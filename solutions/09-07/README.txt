Lesson 09-07 (checkpoint, order summary API) - model answers

09-07-summary.sql   The order summary function ORDER_SUMMARY_JSON.
                    Created through the source member route on a real
                    machine; the SRCSTMF form was NOT run (unverified as of
                    2026-09-29).

Exercise (b): the filled-in script. Replace <your user name>1 with your own
library, and <dollar> with the dollar sign. Write the path expressions with a
heredoc (see 09-02 and 09-04 for the CCSID 273 notes). NOT run on a real
machine (unverified as of 2026-09-29). The call is qualified because
DFTRDBCOL is not known to set the SQL path; an unqualified call from a new
job may give SQL0204.

  CREATE TABLE W0907A (LOW_CNT INTEGER, ORD_NO CHAR(6), ORD_DATE INTEGER,
                       LINE_CNT INTEGER, AMT DECIMAL(11, 2));

  INSERT INTO W0907A
    SELECT T.LOW_CNT, T.ORD_NO, T.ORD_DATE, T.LINE_CNT, T.AMT
      FROM JSON_TABLE(<your user name>1.ORDER_SUMMARY_JSON(3), 'lax <dollar>'
             COLUMNS(LOW_CNT INT PATH 'lax <dollar>.lowStockCount',
                     NESTED PATH 'lax <dollar>.latestOrders[*]'
                     COLUMNS(ORD_NO CHAR(6) PATH 'lax <dollar>.orderNo',
                             ORD_DATE INT PATH 'lax <dollar>.orderDate',
                             LINE_CNT INT PATH 'lax <dollar>.lineCount',
                             AMT DECIMAL(11, 2) PATH 'lax <dollar>.amount')))
           AS T;

Exercise (d): in a copy of ORDER_SUMMARY_JSON with another name and another
SPECIFIC name (at most 10 characters), replace the lowStockCount entry by
   (SELECT COUNT(*) FROM TABLE(<your user name>1.LOW_STOCK()) L)
Qualify the call. NOT run on a real machine (unverified as of 2026-09-29).
An unqualified call inside a function body gave SQL0204 from another job in
09-04 (verified there for another function).

Exercises (a) and (e) have written answers in the lesson itself. Exercise (c)
has no model answer by design.
