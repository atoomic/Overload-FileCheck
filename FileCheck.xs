/*
*
* Copyright (c) 2018, cPanel, LLC.
* All rights reserved.
* http://cpanel.net
*
* This is free software; you can redistribute it and/or modify it under the
* same terms as Perl itself.
*
*/

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <embed.h>

#define NEED_sv_2pv_flags
#include "ppport.h"

#include "FileCheck.h"

/*
*  Macro to make the moking process easier
*     for now keep them there, so we can hack them in the same file
*/

/* generic macro with args */
#define _CALL_REAL_PP(zOP) (* ( gl_overload_ft->op[zOP].real_pp ) )(aTHX)
#define _RETURN_CALL_REAL_PP_IF_UNMOCK(zOP) if (!gl_overload_ft->op[zOP].is_mocked) return _CALL_REAL_PP(zOP);

/* simplified versions for our custom usage */
#define CALL_REAL_OP()                  _CALL_REAL_PP(PL_op->op_type)
#define RETURN_CALL_REAL_OP_IF_UNMOCK() _RETURN_CALL_REAL_PP_IF_UNMOCK(PL_op->op_type)

#define INIT_FILECHECK_MOCK(op_name, op_type, f) \
  newCONSTSUB(stash, op_name,    newSViv(op_type) ); \
  gl_overload_ft->op[op_type].real_pp = PL_ppaddr[op_type]; \
  PL_ppaddr[op_type] = f;

/* ----------- start there --------------- */

OverloadFTOps  *gl_overload_ft = 0;

/*
* common helper to callback the pure perl function Overload::FileCheck::_check
*   and get the mocked value for the -X check
*
*  1 check is true  -> OP returns Yes
*  0 check is false -> OP returns No
*  TODO:            -> OP returns undef
* -1 fallback to the original OP
*/
int _overload_ft_ops() {
  SV *const arg = *PL_stack_sp;
  int optype = PL_op->op_type;  /* this is the current op_type we are mocking */
  int check_status = -1;        /* 1 -> YES ; 0 -> FALSE ; -1 -> delegate */
  int count;

  dSP;

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);
  EXTEND(SP, 2);
  PUSHs(sv_2mortal(newSViv(optype)));
  PUSHs(arg);

  PUTBACK;

  count = call_pv("Overload::FileCheck::_check", G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("No return value from Overload::FileCheck::_check for OP #%d\n", optype);

  check_status = POPi;

  /* printf ("######## The result is %d /// OPTYPE is %d\n", check_status, optype); */

  PUTBACK;
  FREETMPS;
  LEAVE;

  return check_status;
}

/* a generic OP to overload the FT OPs returning yes or no */
PP(pp_overload_ft_yes_no) {
  int check_status;

  assert( gl_overload_ft );

  RETURN_CALL_REAL_OP_IF_UNMOCK();

  check_status = _overload_ft_ops();

  {
    FT_SETUP_dSP_IF_NEEDED;

    if ( check_status == 1 ) FT_RETURNYES;
    if ( check_status == 0 ) FT_RETURNUNDEF;
    /* if ( check_status == -1 ) FT_RETURNUNDEF; */ /* TODO */
  }

  /* fallback */
  return CALL_REAL_OP();
}


MODULE = Overload__FileCheck       PACKAGE = Overload::FileCheck

SV*
mock_op(optype)
     SV* optype;
 ALIAS:
      Overload::FileCheck::_xs_mock_op               = 1
      Overload::FileCheck::_xs_unmock_op             = 2
 CODE:
 {
     /* mylogger = INT2PTR(MyLogger*, SvIV(SvRV(self))); */
      int opid = 0;

      if ( ! SvIOK(optype) )
        croak("first argument to _xs_mock_op / _xs_unmock_op must be one integer");

      opid = SvIV( optype );
      if ( !opid || opid < 0 || opid >= OP_MAX )
          croak( "Invalid opid value %d", opid );

      switch (ix) {
         case 1: /* _xs_mock_op */
              gl_overload_ft->op[opid].is_mocked = 1;
          break;
         case 2: /* _xs_unmock_op */
              gl_overload_ft->op[opid].is_mocked = 0;
          break;
          default:
              croak("Unsupported function at index %d", ix);
              XSRETURN_EMPTY;
      }

      XSRETURN_EMPTY;
 }
 OUTPUT:
     RETVAL

BOOT:
    if (!gl_overload_ft) {
         HV *stash;

         Newxz( gl_overload_ft, 1, OverloadFTOps);

         stash = gv_stashpvn("Overload::FileCheck", 19, TRUE);

         newCONSTSUB(stash, "_loaded", newSViv(1) );

         /* provide constants to standardize return values from mocked functions */
         newCONSTSUB(stash, "CHECK_IS_TRUE",         &PL_sv_yes );   /* could use newSViv(1) or &PL_sv_yes */
         newCONSTSUB(stash, "CHECK_IS_FALSE",        &PL_sv_no );    /* could use newSViv(0) or &PL_sv_no  */         
         
         newCONSTSUB(stash, "FALLBACK_TO_REAL_OP",  newSVnv(-1) );

         /* PP(pp_ftis) - yes/undef/true/false */
         INIT_FILECHECK_MOCK( "OP_FTIS",      OP_FTIS,      &Perl_pp_overload_ft_yes_no);   /* -e */

    }


