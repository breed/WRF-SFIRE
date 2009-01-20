      SUBROUTINE INVMRG(LUBFI,LUBFJ)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    INVMRG
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 1996-10-09
C
C ABSTRACT: THIS SUBROUTINE MERGES "PARTS" OF SUBSETS WHICH HAVE
C   DUPLICATE SPACE AND TIME COORDINATES BUT DIFFERENT OR UNIQUE
C   OBSERVATIONAL DATA.  IT CANNOT MERGE REPLICATED DATA.
C
C PROGRAM HISTORY LOG:
C 1996-10-09  J. WOOLLEN -- ORIGINAL AUTHOR
C 1996-11-25  J. WOOLLEN -- MODIFIED FOR RADIOSONDE CALL SIGNS
C 1998-07-08  J. WOOLLEN -- REPLACED CALL TO CRAY LIBRARY ROUTINE
C                           "ABORT" WITH CALL TO NEW INTERNAL BUFRLIB
C                           ROUTINE "BORT"
C 1999-11-18  J. WOOLLEN -- THE NUMBER OF BUFR FILES WHICH CAN BE
C                           OPENED AT ONE TIME INCREASED FROM 10 TO 32
C                           (NECESSARY IN ORDER TO PROCESS MULTIPLE
C                           BUFR FILES UNDER THE MPI)
C 2002-05-14  J. WOOLLEN -- REMOVED OLD CRAY COMPILER DIRECTIVES;
C                           REMOVED ENTRY POINT MRGINV (IT BECAME A
C                           SEPARATE ROUTINE IN THE BUFRLIB TO
C                           INCREASE PORTABILITY TO OTHER PLATFORMS)
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- MAXJL (MAXIMUM NUMBER OF JUMP/LINK ENTRIES)
C                           INCREASED FROM 15000 TO 16000 (WAS IN
C                           VERIFICATION VERSION); UNIFIED/PORTABLE FOR
C                           WRF; ADDED DOCUMENTATION (INCLUDING
C                           HISTORY); OUTPUTS MORE COMPLETE DIAGNOSTIC
C                           INFO WHEN ROUTINE TERMINATES ABNORMALLY
C
C USAGE:    CALL INVMRG (LUBFI, LUBFJ)
C   INPUT ARGUMENT LIST:
C     LUBFI    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR INPUT BUFR
C                FILE
C     LUBFJ    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR OUTPUT BUFR
C                FILE
C
C REMARKS:
C    THIS ROUTINE CALLS:        BORT     NWORDS   STATUS
C    THIS ROUTINE IS CALLED BY: None
C                               Normally called only by application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MRGCOM/ NRPL,NMRG,NAMB,NTOT
      COMMON /USRINT/ NVAL(NFILES),INV(MAXJL,NFILES),VAL(MAXJL,NFILES)
      COMMON /TABLES/ MAXTAB,NTAB,TAG(MAXJL),TYP(MAXJL),KNT(MAXJL),
     .                JUMP(MAXJL),LINK(MAXJL),JMPB(MAXJL),
     .                IBT(MAXJL),IRF(MAXJL),ISC(MAXJL),
     .                ITP(MAXJL),VALI(MAXJL),KNTI(MAXJL),
     .                ISEQ(MAXJL,2),JSEQ(MAXJL)

      CHARACTER*128 BORT_STR
      CHARACTER*10  TAG
      CHARACTER*3   TYP
      LOGICAL       HEREI,HEREJ,MISSI,MISSJ,SAMEI
      REAL*8        VAL,BMISS

      DATA BMISS /10E10/

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

      IS = 1
      JS = 1

C  GET THE UNIT POINTERS
C  ---------------------

      CALL STATUS(LUBFI,LUNI,IL,IM)
      CALL STATUS(LUBFJ,LUNJ,JL,JM)

C  STEP THROUGH THE BUFFERS COMPARING THE INVENTORY AND MERGING DATA
C  -----------------------------------------------------------------

      DO WHILE(IS.LE.NVAL(LUNI))

C  CHECK TO SEE WE ARE AT THE SAME NODE IN EACH BUFFER
C  ---------------------------------------------------

      NODE = INV(IS,LUNI)
      NODJ = INV(JS,LUNJ)
      IF(NODE.NE.NODJ) GOTO 900

      ITYP = ITP(NODE)

C  FOR TYPE 1 NODES DO AN ENTIRE SEQUENCE REPLACEMENT
C  --------------------------------------------------

      IF(ITYP.EQ.1) THEN
         IF(TYP(NODE).EQ.'DRB') IOFF = 0
         IF(TYP(NODE).NE.'DRB') IOFF = 1
         IWRDS = NWORDS(IS,LUNI)+IOFF
         JWRDS = NWORDS(JS,LUNJ)+IOFF
         IF(IWRDS.GT.IOFF .AND. JWRDS.EQ.IOFF) THEN
            DO N=NVAL(LUNJ),JS+1,-1
            INV(N+IWRDS-JWRDS,LUNJ) = INV(N,LUNJ)
            VAL(N+IWRDS-JWRDS,LUNJ) = VAL(N,LUNJ)
            ENDDO
            DO N=0,IWRDS
            INV(JS+N,LUNJ) = INV(IS+N,LUNI)
            VAL(JS+N,LUNJ) = VAL(IS+N,LUNI)
            ENDDO
            NVAL(LUNJ) = NVAL(LUNJ)+IWRDS-JWRDS
            JWRDS = IWRDS
            NRPL = NRPL+1
         ENDIF
         IS = IS+IWRDS
         JS = JS+JWRDS
      ENDIF

C  FOR TYPES 2 AND 3 FILL MISSINGS
C  -------------------------------

      IF(ITYP.EQ.2) THEN
         HEREI = VAL(IS,LUNI).LT.BMISS
         HEREJ = VAL(JS,LUNJ).LT.BMISS
         MISSI = VAL(IS,LUNI).GE.BMISS
         MISSJ = VAL(JS,LUNJ).GE.BMISS
         SAMEI = VAL(IS,LUNI).EQ.VAL(JS,LUNJ)
         IF(HEREI.AND.MISSJ) THEN
            VAL(JS,LUNJ) = VAL(IS,LUNI)
            NMRG = NMRG+1
         ELSEIF(HEREI.AND.HEREJ.AND..NOT.SAMEI) THEN
            NAMB = NAMB+1
         ENDIF
      ENDIF

      IF(ITYP.EQ.3) THEN
         HEREI = VAL(IS,LUNI).NE.BMISS
         HEREJ = VAL(JS,LUNJ).NE.BMISS
         MISSI = VAL(IS,LUNI).EQ.BMISS
         MISSJ = VAL(JS,LUNJ).EQ.BMISS
         SAMEI = VAL(IS,LUNI).EQ.VAL(JS,LUNJ)
         IF(HEREI.AND.MISSJ) THEN
            VAL(JS,LUNJ) = VAL(IS,LUNI)
            NMRG = NMRG+1
         ELSEIF(HEREI.AND.HEREJ.AND..NOT.SAMEI) THEN
            NAMB = NAMB+1
         ENDIF
      ENDIF

C  BUMP THE COUNTERS AND GO CHECK THE NEXT PAIR
C  --------------------------------------------

      IS = IS + 1
      JS = JS + 1
      ENDDO

      NTOT = NTOT+1

C  EXITS
C  -----

      RETURN
900   WRITE(BORT_STR,'("BUFRLIB: INVMRG - NODE FROM INPUT BUFR FILE '//
     . '(",I7,") DOES NOT EQUAL NODE FROM OUTPUT BUFR FILE (",I7,"), '//
     . 'TABULAR MISMATCH")') NODE,NODJ
      CALL BORT(BORT_STR)
      END
