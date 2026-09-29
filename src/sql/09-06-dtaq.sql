-- 09-06: talk to a short-lived worker through data queues.
-- See docs/part09/09-06-data-queues.md
-- Run this file statement by statement (ACS Run SQL Scripts), NOT as one batch:
-- you have to start the worker between the steps (see the lesson).
-- Do NOT copy it into a source-physical-file member.
-- CURRENT SCHEMA is your development library, so no library name is written
-- here. Queue Z0906A carries the requests, queue Z0906B the replies.
-- Write a comma followed by a space in every list (PUB400 uses a decimal comma).
-- Parameter names below follow the IBM documentation; the lesson's verification
-- (verify/part09-06-dtaq) is the place where they are confirmed on PUB400.

-- 1. Send requests. The worker (C0906A) reads them in the order they arrive.
--    The first word decides what the worker does: ECHO, EXIST, STOCK or END.
CALL QSYS2.SEND_DATA_QUEUE(
       MESSAGE_DATA => 'ECHO HELLO',
       DATA_QUEUE => 'Z0906A',
       DATA_QUEUE_LIBRARY => CURRENT SCHEMA);

CALL QSYS2.SEND_DATA_QUEUE(
       MESSAGE_DATA => 'EXIST ZAIKOM',
       DATA_QUEUE => 'Z0906A',
       DATA_QUEUE_LIBRARY => CURRENT SCHEMA);

CALL QSYS2.SEND_DATA_QUEUE(
       MESSAGE_DATA => 'STOCK P00002',
       DATA_QUEUE => 'Z0906A',
       DATA_QUEUE_LIBRARY => CURRENT SCHEMA);

-- 2. Submit the worker from a 5250 session (see the lesson), then read one
--    reply. WAIT_TIME is in seconds: the call gives up after 30 seconds
--    instead of waiting forever. Run this statement again for the next reply.
SELECT *
  FROM TABLE(QSYS2.RECEIVE_DATA_QUEUE(
         DATA_QUEUE => 'Z0906B',
         DATA_QUEUE_LIBRARY => CURRENT SCHEMA,
         WAIT_TIME => 30)) AS R;

-- 3. What did the worker do? It writes one row per step into W0906A.
--    The STOCK request lands here (the worker cannot return the number itself).
SELECT SEQ, TS, PHASE, MSG
  FROM W0906A
 ORDER BY SEQ;

-- 4. Ask the worker to stop, then read its last reply (BYE ...).
CALL QSYS2.SEND_DATA_QUEUE(
       MESSAGE_DATA => 'END',
       DATA_QUEUE => 'Z0906A',
       DATA_QUEUE_LIBRARY => CURRENT SCHEMA);

SELECT *
  FROM TABLE(QSYS2.RECEIVE_DATA_QUEUE(
         DATA_QUEUE => 'Z0906B',
         DATA_QUEUE_LIBRARY => CURRENT SCHEMA,
         WAIT_TIME => 30)) AS R;

-- 5. Nothing there means: the wait ran out (an empty result, not an error).
--    A worker that waits six times without a request ends by itself (2 min).
