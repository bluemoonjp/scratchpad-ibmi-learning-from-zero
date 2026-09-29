# Rules.mk for the lesson 10-03 flat clone (Capstone D).
# Put this file next to iproj.json (see templates/part08-zaisrv/iproj.json
# and the 08-02/08-08 lessons). Source files sit in the same directory:
#   zaisrv.rpgle  zaisrv.bnd  za0500s.sqlrpgle
# Copy them from solutions/07-05 and solutions/10-03 (flat layout, no
# sub-directories).
#
# The first two rules are the ones from templates/part08-zaisrv/Rules.mk.
# The last two are the additions for ZA0500.
#
# STATUS: UNVERIFIED (2026-09-30). Whether makei builds an embedded-SQL
# member (.sqlrpgle) and a *PGM that binds a service program with these
# rules is exactly what verify/part10-03-modernize tries. If makei cannot
# do it, build ZA0500 by hand with CRTSQLRPGI (see za0500s.sqlrpgle) and
# let makei build only ZAISRV.
#
# NOTE (UNVERIFIED): makei builds ZA0500.MODULE first (CRTSQLRPGI with
# OBJTYPE(*MODULE)). The ctl-opt keywords DFTACTGRP and ACTGRP of the
# model answer are valid only for CRTBNDRPG (ILE RPG reference), so the
# verify batch removes them from its flat-clone copy. If your makei build
# stops on that line, remove those two keywords in the clone copy only
# and keep the bnddir keyword.

ZAISRV.MODULE: zaisrv.rpgle
ZAISRV.SRVPGM: ZAISRV.MODULE zaisrv.bnd

ZA0500.MODULE: za0500s.sqlrpgle
ZA0500.PGM: ZA0500.MODULE ZAISRV.SRVPGM
