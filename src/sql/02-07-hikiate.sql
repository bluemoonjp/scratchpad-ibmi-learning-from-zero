-- 02-07: stock allocation for order J00001 (P00001 x2, P00003 x5).
-- Always SELECT with the same WHERE before an UPDATE. See docs/part02/02-07-sql-update.md

-- 1. Check current stock before allocating
SELECT ZASHO, ZASU FROM ZAIKOM WHERE ZASHO IN ('P00001', 'P00003');

-- 2. Allocate (reduce stock by the ordered quantity)
UPDATE ZAIKOM SET ZASU = ZASU - 2 WHERE ZASHO = 'P00001';
UPDATE ZAIKOM SET ZASU = ZASU - 5 WHERE ZASHO = 'P00003';

-- 3. Confirm the new stock
SELECT ZASHO, ZASU FROM ZAIKOM WHERE ZASHO IN ('P00001', 'P00003');
