CREATE OR REPLACE TRIGGER tau_lib_borrow_return
AFTER UPDATE OF return_date ON lib_borrow FOR EACH ROW
BEGIN
    IF :NEW.return_date IS NOT NULL THEN
        INSERT INTO lib_borrow_history (id, item_id, card_id, start_date, max_date, return_date)
        VALUES (:OLD.id, :OLD.item_id, :OLD.card_id, :OLD.start_date, :OLD.max_date, :NEW.return_date);
    END IF;
END;