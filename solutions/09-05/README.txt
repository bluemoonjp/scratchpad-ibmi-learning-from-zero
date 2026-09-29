Lesson 09-05 (external API: adapter and mock) - model answers

parse-zip.sql   The .sql script the learner writes as the exercise.
                Creates the view APIZIP that reads the response text
                stored in APILOG.RESP with JSON_TABLE (status, prefecture
                code and the three address parts) and selects from it.
                The adapter itself (src/qrpglesrc/juhttpsv.sqlrpgle) never
                parses JSON.

Related files outside this folder:
  src/qrpglesrc/juhttpsv.sqlrpgle   adapter (mock or real, logs to APILOG)
  db/mock/apimock.sql               APICFG, APIMOCK and APILOG tables
