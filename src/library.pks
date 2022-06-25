CREATE OR REPLACE PACKAGE library_pkg AS

PROCEDURE AddAuthor(pvc_LastName  IN lib_author.last_name%TYPE,
                    pvc_FirstName IN lib_author.first_name%TYPE DEFAULT NULL,
                    pvc_Country   IN lib_author.country%TYPE DEFAULT NULL,
                    pnu_BirthYear IN lib_author.birth_year%TYPE DEFAULT NULL,
                    pnu_DeathYear IN lib_author.death_year%TYPE DEFAULT NULL);

PROCEDURE AddBook(pnu_AuthorId  IN lib_author.id%TYPE,
                  pvc_Title     IN lib_book.title%TYPE,
                  pvc_Isbn      IN lib_book.isbn%TYPE,
                  pvc_Publisher IN lib_book.publisher%TYPE,
                  pnu_Year      IN lib_book.year%TYPE,
                  pnu_Pages     IN lib_book.pages%TYPE,
                  pvc_Language  IN lib_book.language%TYPE DEFAULT 'EN');

PROCEDURE AddItem(pnu_BookId IN lib_book.id%TYPE,
                  pnu_Copies IN PLS_INTEGER DEFAULT 1);

PROCEDURE RegisterCustomer(pvc_FirstName IN lib_customer.first_name%TYPE,
                           pvc_LastName  IN lib_customer.last_name%TYPE,
                           pvc_Address   IN lib_customer.address%TYPE,
                           pdt_BirthDate IN lib_customer.birth_date%TYPE,
                           pvc_Email     IN lib_customer.email%TYPE,
                           pvc_Phone     IN lib_customer.phone%TYPE,
                           pnu_Amount    IN lib_payment.amount%TYPE);

PROCEDURE CreateNewCard(pnu_CustomerId IN lib_customer.id%TYPE);

PROCEDURE ManageFunds(pnu_CustomerId IN lib_customer.id%TYPE,
                      pnu_Amount     IN lib_payment.amount%TYPE,
                      pvc_Type       IN lib_payment.type%TYPE);

PROCEDURE DisplayCustomerInfo(pnu_CustomerId IN lib_customer.id%TYPE);

PROCEDURE BorrowBook(pnu_CustomerId IN lib_customer.id%TYPE,
                     pnu_BookId     IN lib_book.id%TYPE);

PROCEDURE ReturnBook(pnu_CustomerId IN lib_customer.id%TYPE,
                     pnu_ItemId     IN lib_item.id%TYPE,
                     pbo_Damaged    IN BOOLEAN DEFAULT FALSE);

END library_pkg;
/