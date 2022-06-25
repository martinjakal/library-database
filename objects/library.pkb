CREATE OR REPLACE PACKAGE BODY library_pkg AS

------------------------------------------------------------------------------------------------

gnu_DaysActiveCard        CONSTANT PLS_INTEGER := 365;
gnu_DaysMaxBorrow         CONSTANT PLS_INTEGER := 30;

gnu_CostActivateCard      CONSTANT PLS_INTEGER := -200;
gnu_CostBookDamage        CONSTANT PLS_INTEGER := -100;
gnu_CostLateReturn        CONSTANT PLS_INTEGER := -50;

gnu_StatusCardInactive    CONSTANT PLS_INTEGER := 0;
gnu_StatusCardActive      CONSTANT PLS_INTEGER := 1;
gnu_StatusCardDisabled    CONSTANT PLS_INTEGER := 2;

exc_InactiveCard          EXCEPTION;
exc_InsufficientFunds     EXCEPTION;

------------------------------------------------------------------------------------------------

FUNCTION FetchCardId(pnu_CustomerId IN lib_customer.id%TYPE)
    RETURN NUMBER
IS
    vnu_CardId    lib_card.id%TYPE;
BEGIN
    SELECT id INTO vnu_CardId FROM lib_card
    WHERE customer_id = pnu_CustomerId AND status <> gnu_StatusCardDisabled;

    RETURN vnu_CardId;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Customer has no valid card.');
        RETURN vnu_CardId;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Fetch card id failed.');
        RETURN vnu_CardId;
END FetchCardId;

------------------------------------------------------------------------------------------------

FUNCTION VerifyCard(pnu_CardId IN lib_card.id%TYPE)
    RETURN BOOLEAN
IS
    vnu_CardStatus          lib_card.status%TYPE;
    vdt_DeactivationDate    lib_card.deactivation_date%TYPE;
BEGIN
    SELECT status, deactivation_date INTO vnu_CardStatus, vdt_DeactivationDate
    FROM lib_card WHERE id = pnu_CardId;

    IF vnu_CardStatus <> gnu_StatusCardActive THEN
        RETURN FALSE;
    ELSIF SYSDATE > vdt_DeactivationDate THEN
        UPDATE lib_card
        SET status = gnu_StatusCardInactive
        WHERE id = pnu_CardId;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Making card inactive because it has expired.');
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Verify card failed.');
        RETURN FALSE;
END VerifyCard;

------------------------------------------------------------------------------------------------

PROCEDURE MakePayment(pnu_CustomerId IN lib_customer.id%TYPE,
                      pnu_Amount     IN lib_payment.amount%TYPE,
                      pvc_Type       IN lib_payment.type%TYPE)
IS
    vnu_CurBalance    lib_customer.balance%TYPE;
    vnu_NewBalance    lib_customer.balance%TYPE;
BEGIN
    SELECT balance INTO vnu_CurBalance FROM lib_customer WHERE id = pnu_CustomerId;

    IF pvc_Type <> 'DEPOSIT' AND ABS(pnu_Amount) > vnu_CurBalance THEN
        RAISE exc_InsufficientFunds;
    END IF;

    vnu_NewBalance := vnu_CurBalance + pnu_Amount;
    INSERT INTO lib_payment (id, customer_id, amount, balance_old, balance_new, payment_date, type)
    VALUES (seq_lib_payment_id.NEXTVAL, pnu_CustomerId, pnu_Amount, vnu_CurBalance,
            vnu_NewBalance, SYSDATE, pvc_Type);

    UPDATE lib_customer 
    SET balance = vnu_NewBalance
    WHERE id = pnu_CustomerId;
EXCEPTION
    WHEN exc_InsufficientFunds THEN
        DBMS_OUTPUT.PUT_LINE('Insufficient funds to make a payment.');
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Make payment failed.');
        RAISE;
END MakePayment;

------------------------------------------------------------------------------------------------

PROCEDURE ActivateCard(pnu_CustomerId IN lib_customer.id%TYPE)
IS
    vnu_CardId    lib_card.id%TYPE;
BEGIN
    vnu_CardId := FetchCardId(pnu_CustomerId);
    MakePayment(pnu_CustomerId, gnu_CostActivateCard, 'CARD');

    UPDATE lib_card
    SET status = gnu_StatusCardActive,
        activation_date = SYSDATE,
        deactivation_date = SYSDATE + gnu_DaysActiveCard
    WHERE id = vnu_CardId;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Activate card failed.');
        RAISE;
END ActivateCard;

------------------------------------------------------------------------------------------------

PROCEDURE AddAuthor(pvc_LastName  IN lib_author.last_name%TYPE,
                    pvc_FirstName IN lib_author.first_name%TYPE DEFAULT NULL,
                    pvc_Country   IN lib_author.country%TYPE DEFAULT NULL,
                    pnu_BirthYear IN lib_author.birth_year%TYPE DEFAULT NULL,
                    pnu_DeathYear IN lib_author.death_year%TYPE DEFAULT NULL)
IS
BEGIN
    INSERT INTO lib_author (id, first_name, last_name, country, birth_year, death_year)
    VALUES (seq_lib_author_id.NEXTVAL, pvc_FirstName, pvc_LastName, pvc_Country, pnu_BirthYear, pnu_DeathYear);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Added author.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Add author failed.');
END AddAuthor;

------------------------------------------------------------------------------------------------

PROCEDURE AddBook(pnu_AuthorId  IN lib_author.id%TYPE,
                  pvc_Title     IN lib_book.title%TYPE,
                  pvc_Isbn      IN lib_book.isbn%TYPE,
                  pvc_Publisher IN lib_book.publisher%TYPE,
                  pnu_Year      IN lib_book.year%TYPE,
                  pnu_Pages     IN lib_book.pages%TYPE,
                  pvc_Language  IN lib_book.language%TYPE DEFAULT 'EN')
IS
BEGIN
    INSERT INTO lib_book (id, author_id, title, isbn, publisher, year, pages, language)
    VALUES (seq_lib_book_id.NEXTVAL, pnu_AuthorId, pvc_Title, pvc_Isbn, pvc_Publisher, pnu_Year, pnu_Pages, pvc_Language);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Added book.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Add book failed.');
END AddBook;

------------------------------------------------------------------------------------------------

PROCEDURE AddItem(pnu_BookId IN lib_book.id%TYPE,
                  pnu_Copies IN PLS_INTEGER DEFAULT 1)
IS
BEGIN
    FOR i IN 1..pnu_Copies LOOP
        INSERT INTO lib_item (id, book_id, available)
        VALUES (seq_lib_item_id.NEXTVAL, pnu_BookId, 'YES');
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Added item.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Add item failed.');
END AddItem;

------------------------------------------------------------------------------------------------

PROCEDURE RegisterCustomer(pvc_FirstName IN lib_customer.first_name%TYPE,
                           pvc_LastName  IN lib_customer.last_name%TYPE,
                           pvc_Address   IN lib_customer.address%TYPE,
                           pdt_BirthDate IN lib_customer.birth_date%TYPE,
                           pvc_Email     IN lib_customer.email%TYPE,
                           pvc_Phone     IN lib_customer.phone%TYPE,
                           pnu_Amount    IN lib_payment.amount%TYPE)
IS
    vnu_CustomerId    lib_customer.id%TYPE;
BEGIN
    IF pnu_Amount < ABS(gnu_CostActivateCard) THEN
        RAISE exc_InsufficientFunds;
    END IF;

    vnu_CustomerId := seq_lib_customer_id.NEXTVAL;

    INSERT INTO lib_customer (id, first_name, last_name, address, birth_date, email, phone)
    VALUES (vnu_CustomerId, pvc_FirstName, pvc_LastName, pvc_Address, pdt_BirthDate, pvc_Email, pvc_Phone);

    MakePayment(vnu_CustomerId, pnu_Amount, 'DEPOSIT');
    CreateNewCard(vnu_CustomerId);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Registered customer.');
EXCEPTION
    WHEN exc_InsufficientFunds THEN
        DBMS_OUTPUT.PUT_LINE('Must deposit at least the cost of card activation.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Register customer failed.');
END RegisterCustomer;

------------------------------------------------------------------------------------------------

PROCEDURE CreateNewCard(pnu_CustomerId IN lib_customer.id%TYPE)
IS
    vnu_OldCardId    lib_card.id%TYPE;
    vnu_NewCardId    lib_card.id%TYPE;
BEGIN
    -- discard old card if there is any (loss, theft)
    vnu_OldCardId := FetchCardId(pnu_CustomerId);
    vnu_NewCardId := seq_lib_card_id.NEXTVAL;

    INSERT INTO lib_card (id, customer_id, status)
    VALUES (vnu_NewCardId, pnu_CustomerId, gnu_StatusCardInactive);

    ActivateCard(pnu_CustomerId);

    -- clean after the old card
    IF vnu_OldCardId IS NOT NULL THEN
        UPDATE lib_card
        SET status = gnu_StatusCardDisabled,
            deactivation_date = SYSDATE
        WHERE id = vnu_OldCardId;

        UPDATE lib_borrow
        SET card_id = vnu_NewCardId
        WHERE card_id = vnu_OldCardId;
    END IF;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('New card created.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Create new card failed.');
END CreateNewCard;

------------------------------------------------------------------------------------------------

PROCEDURE ManageFunds(pnu_CustomerId IN lib_customer.id%TYPE,
                      pnu_Amount     IN lib_payment.amount%TYPE,
                      pvc_Type       IN lib_payment.type%TYPE)
IS
    vnu_CurBalance    lib_customer.balance%TYPE;
BEGIN
    -- wrapper function to restrict allowed operations of the customer
    IF pvc_Type IN ('DEPOSIT', 'WITHDRAW') THEN
        MakePayment(pnu_CustomerId, pnu_Amount, pvc_Type);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Payment accepted.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Invalid operation in manage funds.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Manage funds failed.');
END ManageFunds;

------------------------------------------------------------------------------------------------

PROCEDURE DisplayCustomerInfo(pnu_CustomerId IN lib_customer.id%TYPE)
IS
    vnu_CardId           lib_card.id%TYPE;
    vnu_BorrowCount      PLS_INTEGER;
    vnu_BorrowCounter    PLS_INTEGER := 0;
BEGIN
    vnu_CardId := FetchCardId(pnu_CustomerId);
    SELECT COUNT(*) INTO vnu_BorrowCount FROM lib_borrow WHERE card_id = vnu_CardId;

    DBMS_OUTPUT.PUT_LINE('Customer ' || pnu_CustomerId);
    DBMS_OUTPUT.PUT_LINE('------------------------------');
    FOR c IN (SELECT * FROM lib_customer WHERE id = pnu_CustomerId) LOOP
        DBMS_OUTPUT.PUT_LINE('Name: ' || c.first_name || ' ' || c.last_name);
        DBMS_OUTPUT.PUT_LINE('Address: ' || c.address);
        DBMS_OUTPUT.PUT_LINE('Birth date: ' || c.birth_date);
        DBMS_OUTPUT.PUT_LINE('Email: ' || c.email);
        DBMS_OUTPUT.PUT_LINE('Phone: ' || c.phone);
        DBMS_OUTPUT.PUT_LINE('Card ID: ' || vnu_CardId);
        DBMS_OUTPUT.PUT_LINE('Balance: ' || c.balance);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('------------------------------');

    IF vnu_BorrowCount = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No active borrows.');
        DBMS_OUTPUT.PUT_LINE('------------------------------');
    ELSE
        FOR c IN (SELECT br.start_date, br.max_date, bo.title, au.first_name, au.last_name
                  FROM lib_borrow br
                  JOIN lib_item it ON it.id = br.item_id
                  JOIN lib_book bo ON bo.id = it.book_id
                  JOIN lib_author au ON au.id = bo.author_id
                  WHERE br.card_id = vnu_CardId) LOOP
            vnu_BorrowCounter := vnu_BorrowCounter + 1;
            DBMS_OUTPUT.PUT_LINE('Borrow ' || vnu_BorrowCounter || ' / ' || vnu_BorrowCount);
            DBMS_OUTPUT.PUT_LINE('Title: ' || c.title);
            DBMS_OUTPUT.PUT_LINE('Author: ' || c.first_name || ' ' || c.last_name);
            DBMS_OUTPUT.PUT_LINE('Date: ' || c.start_date || ' - ' || c.max_date);
            DBMS_OUTPUT.PUT_LINE('------------------------------');
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Display customer info failed.');
END DisplayCustomerInfo;

------------------------------------------------------------------------------------------------

PROCEDURE BorrowBook(pnu_CustomerId IN lib_customer.id%TYPE,
                     pnu_BookId     IN lib_book.id%TYPE)
IS
    vnu_CardId             lib_card.id%TYPE;
    vnu_ItemId             lib_item.id%TYPE;
    vnu_CopiesAvailable    PLS_INTEGER;
BEGIN
    vnu_CardId := FetchCardId(pnu_CustomerId);

    IF VerifyCard(vnu_CardId) = FALSE THEN
        RAISE exc_InactiveCard;
    END IF;

    SELECT MIN(id), COUNT(*) INTO vnu_ItemId, vnu_CopiesAvailable FROM lib_item
    WHERE book_id = pnu_BookId AND available = 'YES';

    IF vnu_CopiesAvailable > 0 THEN
        INSERT INTO lib_borrow (id, item_id, card_id, start_date, max_date)
        VALUES (seq_lib_borrow_id.NEXTVAL, vnu_ItemId, vnu_CardId, SYSDATE, SYSDATE + gnu_DaysMaxBorrow);

        UPDATE lib_item
        SET available = 'NO'
        WHERE id = vnu_ItemId;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Book borrowed.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('No copies of the book are available.');
    END IF;
EXCEPTION
    WHEN exc_InactiveCard THEN
        DBMS_OUTPUT.PUT_LINE('Invalid borrow because card is inactive.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Borrow book failed.');
END BorrowBook;

------------------------------------------------------------------------------------------------

PROCEDURE ReturnBook(pnu_CustomerId IN lib_customer.id%TYPE,
                     pnu_ItemId     IN lib_item.id%TYPE,
                     pbo_Damaged    IN BOOLEAN DEFAULT FALSE)
IS
    vnu_CardId        lib_card.id%TYPE;
    vnu_BorrowId      lib_borrow.id%TYPE;
    vdt_MaxDate       lib_borrow.max_date%TYPE;
    vbo_ActiveCard    BOOLEAN;
BEGIN
    vnu_CardId := FetchCardId(pnu_CustomerId);
    SELECT id, max_date INTO vnu_BorrowId, vdt_MaxDate FROM lib_borrow WHERE item_id = pnu_ItemId;

    IF pbo_Damaged = TRUE THEN
        MakePayment(pnu_CustomerId, gnu_CostBookDamage, 'DAMAGE');
    END IF; 

    IF SYSDATE > vdt_MaxDate THEN
        MakePayment(pnu_CustomerId, gnu_CostLateReturn, 'LATE');
    END IF;

    -- history of borrows is stored in the separate table with the same structure
    -- moving of finished borrows is handled by trigger tau_lib_borrow_return
    UPDATE lib_borrow
    SET return_date = SYSDATE
    WHERE id = vnu_BorrowId;
    DELETE FROM lib_borrow
    WHERE id = vnu_BorrowId;

    UPDATE lib_item
    SET available = 'YES'
    WHERE id = pnu_ItemId;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Book returned.');

    -- books can be returned even with inactive card
    vbo_ActiveCard := VerifyCard(vnu_CardId);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Return book failed.');
END ReturnBook;

------------------------------------------------------------------------------------------------

END library_pkg;
/