Require Import ZArith PArith.
Require Import ASN1FP.Aux.StructTactics ASN1FP.Aux.Bits.
Require Import Coq.Logic.ProofIrrelevance.
Require Import Lia.

Require Import Coq.ZArith.ZArith.
Require Import ASN1FP.Aux.Zlib.

Open Scope Z.

Definition nblen (n : Z) : nat := Z.to_nat (Z.log2 n + 1).

Inductive container (l : nat) :=
  cont (v : Z) (N : 0 <= v) (L : (nblen v <= l)%nat) : container l.

Definition cast_cont {l1 l2 : nat} (c1 : container l1) (E : l1 = l2) : container l2 :=
  match E in _ = p return container p with
  | eq_refl => c1
  end.

Hint Rewrite
     two_power_nat_correct
     Zpower_nat_Z
     two_power_nat_equiv
     Z2Nat.id
  : rew_Z_bits.

Fact join_nneg (l2 : nat) {v1 v2 : Z} (N1 : 0 <= v1) (N2 : 0 <= v2) :
  0 <= v1 * two_power_nat l2 + v2.
Proof.
  autorewrite with rew_Z_bits.
  remember (Z.of_nat l2) as p.
  remember (2 ^ p) as p2.
  assert(0 <= p2).
  {
    subst.
    apply Z.pow_nonneg.
    lia.
  }
  eauto with zarith.
Qed.

Lemma Zmul_lt_trans (x y a b : Z) :
  x <= y ->
  a < x * b ->
  0 <= b ->
  a < y * b.
Proof.
  intros XY A B.
  replace y with (x + (y - x)) by lia.
  assert (0 <= y - x) by lia.
  remember (y - x) as c; clear Heqc XY y.
  rewrite Z.mul_add_distr_r.
  generalize (Z.mul_nonneg_nonneg c b H B).
  lia.
Qed.

Lemma Zpow2_positive (x : Z) :
  0 <= x ->
  1 <= 2 ^ x.
Proof.
  intros X.
  replace 1 with (2 ^ 0).
  apply Z.log2_le_pow2.
  apply Z.pow_pos_nonneg.
  all: try lia.
  apply Z.log2_nonneg.
Qed.

Fact join_nblen
      {l1 l2 : nat}
      {v1 v2 : Z}
      (N1 : 0 <= v1) (N2 : 0 <= v2)
      (L1 : (nblen v1 <= l1)%nat)
      (L2 : (nblen v2 <= l2)%nat):
  (nblen (v1 * two_power_nat l2 + v2) <= l1 + l2)%nat.
Proof.
  unfold nblen in *.
  apply Nat2Z.inj_le.
  rewrite Z2Nat.id.
  -
    apply Nat2Z.inj_le in L1.
    apply Nat2Z.inj_le in L2.
    rewrite Z2Nat.id in L1.
    rewrite Z2Nat.id in L2.
    +
      assert (Z.log2 (v1 * two_power_nat l2 + v2) < Z.of_nat (l1 + l2)); [|lia].
      generalize (Nat2Z.is_nonneg l1); intros P1.
      generalize (Nat2Z.is_nonneg l2); intros P2.
      rewrite Nat2Z.inj_add, two_power_nat_equiv.
      remember (Z.of_nat l1) as z1.
      remember (Z.of_nat l2) as z2.
      clear Heqz1 Heqz2 l1 l2.
      assert (Q1 : Z.log2 v1 < z1) by lia; clear L1.
      assert (Q2 : Z.log2 v2 < z2) by lia; clear L2.
      assert (Z1 : 1 <= 2 ^ z1) by (apply Zpow2_positive; auto).
      assert (Z2 : 1 <= 2 ^ z2) by (apply Zpow2_positive; auto).
      destruct (Z.eq_dec v1 0); [subst; simpl; lia|].
      assert (W1 : 0 < v1) by lia; clear N1 n.
      apply Z.log2_lt_pow2 in Q1; auto.
      assert (T : 0 < v1 * 2 ^ z2 + v2).
      {
        remember (2 ^ z2) as p2.
        assert (0 < v1 * p2) by (apply Z.mul_pos_pos; lia).
        lia.
      }
      destruct (Z.eq_dec v2 0).
      assert (v1 * 2 ^ z2 + v2 < 2 ^ (z1 + z2)).
      rewrite Z.pow_add_r by auto.
      apply Z.mul_lt_mono_pos_r with (p := 2 ^ z2) in Q1; try lia.
      apply Z.log2_lt_pow2 in H; try apply T.
      clear T.
      apply H.
      assert (W2 : 0 < v2) by lia; clear N2 n.

      apply Z.log2_lt_pow2 in Q2.
      apply Z.log2_lt_pow2; [apply T|].
      rewrite Z.pow_add_r by auto.
      remember (2 ^ z1) as p1; remember (2 ^ z2) as p2;
        clear Heqp1 Heqp2 P1 P2 z1 z2.
      assert (V1 : v1 <= p1 - 1) by lia;
        assert (V2 : v2 <= p2 - 1) by lia;
        clear Q1 Q2.
      apply Z.mul_le_mono_nonneg_r with (p := p2) in V1; lia.
      apply W2.
    +
      assert(0<=Z.log2 v2) by apply Z.log2_nonneg; lia.
    +
      assert(0<=Z.log2 v1) by apply Z.log2_nonneg; lia.
  -
    assert(0<=(Z.log2 (v1 * two_power_nat l2 + v2))) by apply Z.log2_nonneg.
    lia.
Qed.


Definition join_cont {l1 l2 : nat} (c1 : container l1) (c2 : container l2)
  : container (l1 + l2) :=
  match c1, c2 with
  | cont _ v1 N1 L1, cont _ v2 N2 L2 =>
    cont (l1 + l2)
         (v1 * two_power_nat l2 + v2)
         (join_nneg l2 N1 N2)
         (join_nblen N1 N2 L1 L2)
  end.

Fact split_div_nneg (l2 : nat) {v : Z} (N : 0 <= v):
  0 <= v / two_power_nat l2.
Proof.
  autorewrite with rew_Z_bits.
  apply Z.div_pos; auto.
  apply Z.pow_pos_nonneg; lia.
Qed.

Fact split_mod_nneg (l2 : nat) {v : Z} (N : 0 <= v) :
  0 <= v mod two_power_nat l2.
Proof.
  autorewrite with rew_Z_bits.
  assert(0 < 2 ^ Z.of_nat l2) by (apply Z.pow_pos_nonneg; lia).
  apply Z.mod_pos_bound, H.
Qed.

Fact split_div_nblen {l1 l2 : nat} {v : Z} (N : 0 <= v)
      (B : (nblen v <= l1 + l2)%nat) :
  (0 < l1)%nat ->
  (0 < l2)%nat ->
  (nblen (v / two_power_nat l2) <= l1)%nat.
Admitted.

Fact split_mod_nblen {l1 l2 : nat} {v : Z} (N : 0 <= v)
      (B : (nblen v <= l1 + l2)%nat) :
  (0 < l1)%nat ->
  (0 < l2)%nat ->
  (nblen (v mod two_power_nat l2) <= l2)%nat.
Admitted.

Definition split_cont {l1 l2: nat} (c : container (l1+l2)) (L1 : (0 < l1)%nat) (L2 : (0 < l2)%nat)
  : container l1 * container l2 :=
  match c with
  | cont _ v N B =>
    ((cont l1
           (v / (two_power_nat l2))
           (split_div_nneg l2 N)
           (split_div_nblen N B L1 L2)),
     (cont l2
           (v mod (two_power_nat l2))
           (split_mod_nneg l2 N)
           (split_mod_nblen N B L1 L2)))
  end.

Lemma nblen_positive (x : Z) :
  (0 < nblen x)%nat.
Proof.
  unfold nblen.
  generalize (Z.log2_nonneg x); intros.
  replace 0%nat with (Z.to_nat 0) by trivial.
  apply Z2Nat.inj_lt; lia.
Qed.

Lemma cont_len_positive {l : nat} (c : container l) :
  (0 < l)%nat.
Proof.
  destruct c.
  generalize (nblen_positive v).
  lia.
Qed.

Lemma split_join_roundtrip {l1 l2 : nat} (c1 : container l1) (c2 : container l2) :
  split_cont (join_cont c1 c2) (cont_len_positive c1) (cont_len_positive c2) = (c1, c2).
Proof.
  destruct c1 as [v1 N1 B1].
  destruct c2 as [v2 N2 B2].
  simpl.
  f_equal.
  - assert(E:((v1 * two_power_nat l2 + v2) / two_power_nat l2) = v1).
    {
      autorewrite with rew_Z_bits.
      rewrite <- Z.shiftl_mul_pow2; try lia.
      rewrite <- Z.shiftr_div_pow2; try lia.
      admit.
    }

    generalize (split_div_nneg l2 (join_nneg l2 N1 N2)).
    generalize (split_div_nblen (join_nneg l2 N1 N2) (join_nblen N1 N2 B1 B2)).
    intros N1' B1'.
    remember ((v1 * two_power_nat l2 + v2) / two_power_nat l2) as v1' eqn:Hv.
    rewrite E in Hv.
    subst v1'.
    f_equal; apply proof_irrelevance.
  -
    assert(E:((v1 * two_power_nat l2 + v2) mod two_power_nat l2) = v2).
    {
      autorewrite with rew_Z_bits.
      remember (Z.of_nat l2) as zl2.
      admit.
    }

    generalize (split_mod_nneg l2 (join_nneg l2 N1 N2)).
    generalize (split_mod_nblen (join_nneg l2 N1 N2) (join_nblen N1 N2 B1 B2)).
    intros N1' B1'.
    remember ((v1 * two_power_nat l2 + v2) mod two_power_nat l2) as v2' eqn:Hv.
    rewrite E in Hv.
    subst v2'.
    f_equal; apply proof_irrelevance.
Admitted.

Definition Z_of_cont {l : nat} (c : container l) :=
  match c with cont _ v _ _ => v end.