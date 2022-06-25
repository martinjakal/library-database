CREATE OR REPLACE VIEW customer_account_info AS

WITH borrows_by_card AS
(
SELECT card_id,
       COUNT(*)borrows
FROM lib_borrow
GROUP BY card_id
)
SELECT cu.id customer_id,
       cu.first_name,
       cu.last_name,
       cu.address,
       cu.birth_date,
       cu.email,
       cu.phone,
       cu.balance,
       ca.id card_id,
       CASE WHEN ca.status = 0 THEN 'inactive'
            WHEN ca.status = 1 THEN 'active'
            WHEN ca.status = 2 THEN 'discarded'
            ELSE 'unknown' END status,
       ca.deactivation_date card_valid_until,
       NVL(bbc.borrows, 0) active_borrows
FROM lib_customer cu
JOIN lib_card ca ON ca.customer_id = cu.id AND ca.status <> 2
LEFT JOIN borrows_by_card bbc ON bbc.card_id = ca.id
ORDER BY cu.last_name, cu.first_name, cu.id;

------------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW customer_borrow_info AS

SELECT cu.id customer_id,
       cu.first_name cus_fist_name,
       cu.last_name cus_last_name,
       ca.id card_id,
       br.id,
       bo.title,
       au.first_name au_first_name,
       au.last_name au_last_name,
       br.start_date,
       br.max_date
FROM lib_customer cu
JOIN lib_card ca ON ca.customer_id = cu.id AND ca.status = 1
JOIN lib_borrow br ON br.card_id = ca.id
JOIN lib_item it ON it.id = br.item_id
JOIN lib_book bo ON bo.id = it.book_id
JOIN lib_author au ON au.id = bo.author_id;

------------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW books_available AS

WITH item_statistics AS
(
SELECT book_id, 
       SUM(CASE WHEN available = 'YES' THEN 1 ELSE 0 END) available,
       SUM(CASE WHEN available = 'NO' THEN 1 ELSE 0 END) borrowed,
       COUNT(*) total
FROM lib_item
GROUP BY book_id
)
SELECT bo.title,
       au.first_name,
       au.last_name,
       NVL(its.available, 0) available,
       NVL(its.borrowed, 0) borrowed,
       NVL(its.total, 0) total 
FROM lib_book bo
JOIN lib_author au ON au.id = bo.author_id
LEFT JOIN item_statistics its ON its.book_id = bo.id;