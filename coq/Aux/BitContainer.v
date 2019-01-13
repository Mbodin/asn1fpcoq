Require Import ZArith PArith.
Require Import ASN1FP.Aux.StructTactics ASN1FP.Aux.Bits.
Require Import Lia.

Open Scope Z.

Definition nblen (n : Z) : nat := Z.to_nat (Z.log2 n + 1).

Inductive container (l : nat) :=
  cont (v : Z) (N : 0 <= v) (L : (nblen v <= l)%nat) : container l.
  
Definition join_cont {l1 l2 : nat} (c1 : container l1) (c2 : container l2)
  : container (l1 + l2).
Proof.
  destruct c1 as [v1 N1 L1].
  destruct c2 as [v2 N2 L2].
  remember (l1 + l2)%nat as l.
  remember (v1 * (two_power_nat l2) + v2) as v.
  assert (N : 0 <= v).
  {
    subst.
    rewrite two_power_nat_correct.
    rewrite Zpower_nat_Z.
    remember (Z.of_nat l2) as p.
    remember (2 ^ p) as p2.
    assert(0 <= p2).
    {
      subst.
      apply Z.pow_nonneg.
      lia.
    }
    apply Z.add_nonneg_nonneg; auto.
    apply Z.mul_nonneg_nonneg; auto.
  }
  assert (L : (nblen v <= l)%nat).
  {
    unfold nblen in *.
    apply Nat2Z.inj_le.
    rewrite Z2Nat.id.
    -
      subst.
      rewrite two_power_nat_correct in *.
      rewrite Zpower_nat_Z in *.
      admit.
    -
      remember (Z.log2 v) as x.
      assert(0<=x). subst;apply Z.log2_nonneg.
      lia.
  }
  exact (cont l v N L).
Admitted.


Definition split_cont {l1 l2: nat} (c : container (l1+l2))
  : container l1 * container l2.
Proof.
  intros.
  destruct c eqn:C.
Admitted.

Definition cont_cast {l1 l2 : nat} (c1 : container l1) (eq : l1 = l2) : container l2 :=
 match eq in _ = p return container p with
   | eq_refl => c1
 end.

Lemma split_join_roundtrip {l1 l2 : nat} (c1 : container l1) (c2 : container l2) :
  split_cont (join_cont c1 c2) = (c1, c2).
Proof.
Admitted.







(* not sure about this stuff. Review later. Vadim *)

Definition cont_of_Z := cont.

Definition Z_of_cont {l : nat} (c : container l) :=
  match c with cont _ v _ _ => v end.

Lemma blen_Z_of_cont {l : nat} (c : container l) :
  (nblen (Z_of_cont c) <= l)%nat.
Proof. destruct c; auto. Qed.

Lemma nonneg_Z_of_cont {l : nat} (c : container l) :
  0 <= Z_of_cont c.
Proof. destruct c; auto. Qed.

Definition cont_Z_roundtrip {l : nat} (c : container l) :=
  match c with
  | cont _ v N L => cont_of_Z l (Z_of_cont c) (nonneg_Z_of_cont c) (blen_Z_of_cont c)
  end.