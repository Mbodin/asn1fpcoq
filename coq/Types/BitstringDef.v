Require Import ZArith.
Require Import ASN1FP.Types.ASNDef ASN1FP.Types.ASNAux
               ASN1FP.Aux.Roundtrip ASN1FP.Aux.Bits ASN1FP.Aux.StructTactics ASN1FP.Aux.Tactics.
Require Import Template.All Switch.Switch Strings.String Lists.List.
Import ListNotations.

Open Scope Z.

Definition real_id_b := 9.

Definition pzero_b   := 2304.
Definition nzero_b   := 590211.
Definition pinf_b    := 590208.
Definition ninf_b    := 590209.
Definition nan_b     := 590210.

Run TemplateProgram
    (mkSwitch Z Z.eqb
              [(pzero_b,    "pzero") ;
                  (nzero_b,     "nzero") ;
                  (pinf_b,       "pinf") ;
                  (ninf_b,       "ninf") ;
                  (nan_b,         "nan")]
              "BER_specials" "classify_BER"
    ).

Inductive BER_bitstring :=
  | special   (val : Z)
  | short (id content_olen type sign base scaling exp_olen_b            exponent significand : Z)
  | long  (id content_olen type sign base scaling       lexp exp_olen_o exponent significand : Z).

Definition BER_bitstring_eqb (b1 b2 : BER_bitstring) : bool :=
  match b1, b2 with
  | special val1, special val2 => Z.eqb val1 val2
  | short id1 co1 t1 s1 bb1 ff1 ee1 e1 m1, short id2 co2 t2 s2 bb2 ff2 ee2 e2 m2 =>
         (id1 =? id2) && (co1 =? co2) && (t1 =? t2) && (s1 =? s2) && (bb1 =? bb2)
      && (ff1 =? ff2) && (ee1 =? ee2) && (e1 =? e2) && (m1 =? m2)
  | long id1 co1 t1 s1 bb1 ff1 ee1 eo1 e1 m1, long id2 co2 t2 s2 bb2 ff2 ee2 eo2 e2 m2 =>
         (id1 =? id2) && (co1 =? co2) && (t1  =?  t2) && (s1 =? s2) && (bb1 =? bb2)
      && (ff1 =? ff2) && (ee1 =? ee2) && (eo1 =? eo2) && (e1 =? e2) && (m1  =?  m2)
  | _, _ => false
  end.

Definition valid_special (val : Z) : bool :=
  match (classify_BER val) with
  | Some _ => true
  | None   => false
  end.

Definition correct_short_co (co e_olen m_olen : Z) : bool :=
  ((e_olen + m_olen) <? co) && (co <? 128).

Definition valid_short (id co t s bb ff ee e m : Z) : bool :=
     (Z.eqb id real_id_b)                  (* identifier is "REAL" *)
  && (correct_short_co co (ee+1) (olen m)) (* encoding length is correct *)
  && (Z.eqb t 1)                           (* encoding is binary *)
  && (Z.ltb (-1)  s) && (Z.ltb  s 2)       (* sign bit is well-formed *)
  && (Z.ltb (-1) bb) && (Z.ltb bb 4)       (* radix bit is well-formed *)
  && (Z.ltb (-1) ff) && (Z.ltb ff 4)       (* scaling factor is well-formed *)
  && (Z.ltb (-1) ee) && (Z.ltb ee 3)       (* exponent length is well-formed *)
  && (Z.ltb (olen e) (ee + 2))             (* exponent length is correct *)
  && (Z.ltb (-1) e)                        (* exponent is non-negative (it is two's complement) *)
  && (Z.ltb 0 m).                          (* mantissa is positive *)

Definition correct_long_co (co e_olen m_olen : Z) : bool :=
  ((e_olen + m_olen + 1) <? co) && (co <? 128).

Definition valid_long (id co t s bb ff ee eo e m : Z) : bool :=
     (Z.eqb id real_id_b)              (* identifier is "REAL" *)
  && (correct_long_co co eo (olen m))  (* encoding length is correct *)
  && (Z.eqb t 1)                       (* encoding is binary *)
  && (Z.ltb (-1)  s) && (Z.ltb  s 2)   (* sign bit is well-formed *)
  && (Z.ltb (-1) bb) && (Z.ltb bb 4)   (* radix bit is well-formed *)
  && (Z.ltb (-1) ff) && (Z.ltb ff 4)   (* scaling factor is well-formed *)
  && (Z.eqb ee 3)                      (* exponent is in long form *)
  && (Z.ltb (-1) eo) && (Z.ltb eo 256) (* exponent length is well-formed *)
  && (Z.ltb (olen e) (eo + 1))         (* exponent length is correct *)
  && (Z.ltb (-1) e)                    (* exponent is non-negative (it is two's complement) *)
  && (Z.ltb 0 m).                      (* mantissa is positive *)

Definition correct_bitstring (b : BER_bitstring) : bool :=
  match b with
  | special val => (valid_special val)
  | short id co t s bb ff ee    e m => (valid_short id co t s bb ff ee    e m)
  | long  id co t s bb ff ee eo e m => (valid_long  id co t s bb ff ee eo e m)
  end.
