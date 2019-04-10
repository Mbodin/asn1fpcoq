Require Import ZArith Lia.
Require Import ASN1FP.Types.BitstringDef
        ASN1FP.Aux.Roundtrip ASN1FP.Aux.Bits
        ASN1FP.Aux.StructTactics ASN1FP.Aux.BitContainer
        ASN1FP.Aux.Tactics ASN1FP.Aux.Option
        ASN1FP.Conversion.Bitstring_Bits.Def.

Definition Some_ize {A B : Type} : (A -> B) -> (A -> option B)
  := Basics.compose Some.

Lemma special_eqb_refl (val : BER_special) :
  special_eqb val val = true.
Proof. destruct val; reflexivity. Qed.
  
Theorem bitstring_bsaux_roundtrip (b : BER_bitstring) :
  roundtrip_option
      BER_bitstring BER_bs_aux BER_bitstring
      (Some_ize bsaux_of_bitstring)
      (Some_ize bitstring_of_bsaux)
      BER_bitstring_eqb
      b.
Proof.
  (* basic simplification *)
  unfold roundtrip_option.
  intros H; clear H.
  unfold bool_het_inverse'; simpl.

  unfold bitstring_of_bsaux, bsaux_of_bitstring.
  repeat break_match; inversion Heqb0; subst.
  - simpl. rewrite special_eqb_refl. reflexivity.
  - clear H7 H8.
    unfold c2z, c2n; simpl.
    inversion Heqb0; subst.
    repeat apply ProofIrrelevance.ProofIrrelevanceTheory.EqdepTheory.inj_pair2 in H0.
    repeat apply ProofIrrelevance.ProofIrrelevanceTheory.EqdepTheory.inj_pair2 in H1.
    rewrite <- H0, <- H1.
    simpl.
    repeat rewrite Z.eqb_refl.
    reflexivity.
  - 
    unfold c2z, c2n; simpl.
    inversion Heqb0; subst.
    repeat apply ProofIrrelevance.ProofIrrelevanceTheory.EqdepTheory.inj_pair2 in H0.
    repeat apply ProofIrrelevance.ProofIrrelevanceTheory.EqdepTheory.inj_pair2 in H1.
    rewrite <- H0, <- H1.
    simpl.
    repeat rewrite Z.eqb_refl.
    reflexivity.
Qed.

Definition cont_eqb {l1 l2 : nat} (c1 : container l1) (c2 : container l2) :=
  match c1, c2 with
  | cont _ v1 _ _, cont _ v2 _ _ => andb (l1 =? l2)%nat (v1 =? v2)
  end.

Infix "=c=" := cont_eqb (at level 50).

Open Scope bool_scope.

Definition BER_nbs_eqb (b1 b2 : BER_nbs) :=
  match b1, b2 with
  | short_nbs id1 co1 t1 s1 bb1 ff1 ee1 e1 m1 _ _ _ _ _,
    short_nbs id2 co2 t2 s2 bb2 ff2 ee2 e2 m2 _ _ _ _ _ =>
    (id1 =c= id2) && (co1 =c= co2) && (t1 =c= t2)   &&
    (s1 =c= s2)   && (bb1 =c= bb2) && (ff1 =c= ff2) &&
    (ee1 =c= ee2) && (e1 =c= e2)   && (m1 =c= m2)
  | long_nbs id1 co1 t1 s1 bb1 ff1 ee1 eo1 e1 m1 _ _ _ _ _,
    long_nbs id2 co2 t2 s2 bb2 ff2 ee2 eo2 e2 m2 _ _ _ _ _ =>
    (id1 =c= id2) && (co1 =c= co2) && (t1 =c= t2)   &&
    (s1 =c= s2)   && (bb1 =c= bb2) && (ff1 =c= ff2) &&
    (ee1 =c= ee2) && (eo1 =c= eo2) && (e1 =c= e2)   &&
    (m1 =c= m2)
  | _, _ => false
  end.

Definition BER_bsaux_eqb (b1 b2 : BER_bs_aux) :=
  match b1, b2 with
  | special_aux z1, special_aux z2 => special_eqb z1 z2
  | normal_aux nbs1, normal_aux nbs2 =>
    BER_nbs_eqb nbs1 nbs2
  | _, _ => false
  end.

Lemma nbs_is_not_special (b : BER_nbs) :
  classify_BER (c2z (cont_of_nbs b)) = None.
Proof.
Admitted.

Theorem bsaux_bits_roundtrip (b : BER_bs_aux) :
  roundtrip_option
      BER_bs_aux Z BER_bs_aux
      (Some_ize Z_of_bsaux)
      bsaux_of_bits
      BER_bsaux_eqb
      b.
Proof.
  unfold roundtrip_option, bool_het_inverse'; simpl; intros T; clear T.
  unfold bsaux_of_bits, Z_of_bsaux.
  repeat break_match; inversion Heqo; clear Heqo; subst; debool.
  - unfold cont_of_bsaux in *.
    break_match.
    + (* special *)
      unfold mk_special_bsaux in *.
      destruct val.
      all: simpl in *.
      all: inversion Heqo0.
      all: reflexivity.
    + (* normal *)
      contradict Heqo0.
      unfold mk_special_bsaux.
      unfold bsaux_nblen.
      rewrite nbs_is_not_special.
      intros H; inversion H.
  - remember (cont_of_bsaux b) as cont_of_b.
    remember (c2z cont_of_b) as bits_of_b.
    unfold BER_bsaux_eqb.
    break_match; subst b.
    + (* was special, decoded as nbs *)
      subst.
      contradict Heqo0.
      unfold mk_special_bsaux, c2z, cont_of_bsaux, bits_of_special, classify_BER.
      simpl.
      repeat break_match; discriminate.
    + rename b0 into b.
      (** * care: might be losing information *)
      clear Heqo0.
      
      unfold bsaux_nblen in cont_of_b;
        unfold cont_of_bsaux in Heqcont_of_b.
      unfold BER_nbs_eqb.
      repeat break_match; subst.
      * (* was short, decoded as short *)
        apply (f_equal Some).

        destruct id as (id, IDN, IDL).
        destruct co as (co, CON, COL).
        destruct  t as ( t,  TN,  TL).
        destruct  s as ( s,  SN,  SL).
        destruct bb as (bb, BBN, BBL).
        destruct ff as (ff, FFN, FFL).
        destruct ee as (ee, EEN, EEL).
        destruct e  as ( e,  EN,  EL).
        destruct m  as ( m,  MN,  ML).

        destruct id0 as (id0, IDN0, IDL0).
        destruct co0 as (co0, CON0, COL0).
        destruct  t0 as ( t0,  TN0,  TL0).
        destruct  s0 as ( s0,  SN0,  SL0).
        destruct bb0 as (bb0, BBN0, BBL0).
        destruct ff0 as (ff0, FFN0, FFL0).
        destruct ee0 as (ee0, EEN0, EEL0).
        destruct e0  as ( e0,  EN0,  EL0).
        destruct m0  as ( m0,  MN0,  ML0).

        unfold cont_eqb.
        unfold c2n, z2n, c2z, Z_of_cont.
        split_andb_goal; debool.


        unfold BER_nblen, cont_of_nbs, append_info, mk_info, mk_content, nbs_nblen, join_cont in *.

  - admit. (* trivial *)
  - admit.
  - admit. (* trivial *)
Admitted.

Theorem bitsrting_bits_roundtrip (b : BER_bitstring) :
  roundtrip_option
      BER_bitstring Z BER_bitstring
      (Some_ize bits_of_bitstring)
      bitstring_of_bits
      BER_bitstring_eqb
      b.
Admitted.