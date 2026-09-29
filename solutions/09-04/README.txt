Lesson 09-04 (API boundary: SQL routines) - model answers

lowstockb.sql   Exercise (a) 3: the table function LOW_STOCK_BELOW.
                NOT run on a real machine (unverified as of 2026-09-29).

Exercise (a) 1 (run it with db2 over SSH; replace <your user name>1 with
your own library; NOT run as this exact statement, unverified as of
2026-09-29):

  db2 "SELECT * FROM TABLE(<your user name>1.LOW_STOCK()) X WHERE PRODUCT_CODE = 'P00005'"
