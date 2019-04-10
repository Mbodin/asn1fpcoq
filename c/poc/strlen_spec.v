(** This is a toy example to demonstrate how to specify and prove correct a C function using C light *)


From Coq Require Import String List ZArith.
From compcert Require Import Coqlib Integers Floats AST Ctypes Cop Clight Clightdefs Memory Values.
(* Local Open Scope Z_scope.*)


(** High-level functional specification *)

Inductive string_length : string -> nat -> Prop :=
| ZeroLen : string_length EmptyString 0
| SuccLen : forall (n : nat) (s : string) (c : Ascii.ascii) , string_length s n -> string_length (String c s) (S n).
    
Definition strlen_fun := String.length.

Parameter strlen_fun_correct : forall (s : string), string_length s (strlen_fun s).

(* Strings as list of bytes *)

Fixpoint string_to_list_byte (s: string) : list byte :=
  match s with
  | EmptyString => nil
  | String a s' => Byte.repr (Z.of_N (Ascii.N_of_ascii a)) :: string_to_list_byte s'
  end.

Definition strlen_byte (bs : list byte) := List.length bs.

Lemma length_string_byte_equiv : forall s, String.length s = strlen_byte (string_to_list_byte s).
Proof.
  induction s.
  - simpl. reflexivity.
  - simpl. rewrite <- IHs. reflexivity.
Qed.

Parameter strlen_byte_correct : forall (s : string), string_length s (strlen_byte (string_to_list_byte s)).

(* Connection high-level and low-level specification *)

(* Address (b,ofs) is a block b an offset ofs *)

Definition addr : Type := (Values.block*Z).
Definition block_of (addr : addr) := match addr with (b,_) => b end.
(* Valid block in m *)
Definition valid_block_b (m : mem) (b : Values.block):=
  plt b (Memory.Mem.nextblock m).

(* Assume the low-level spec outputs the values read *)
Parameter strlen_C_byte : mem -> addr -> option (Z*mem*list byte).

Definition strlen_C_correct := forall m p z m' bs, strlen_C_byte m p = Some (z,m',bs) -> Z.of_nat (strlen_byte bs) = z.

(** Low-level specification *)

Inductive strlen_spec_C : mem -> addr -> option (Z*mem) -> Prop :=
| UninitMemory : forall m addr, not (Mem.valid_block m (block_of addr)) -> strlen_spec_C m addr None. (* Block of addr is not initialized in m *)
(*TODO *)

(* true if the integer value read is zero - end of string *)
Definition is_null (v : Values.val) :=
  match v with
  | Vint zero => true
  | _ => false
  end.

Definition chunk : memory_chunk := Mint8unsigned. (* not quite sure how to deal with the memory chunks *)
Definition INTSIZE := (nat_of_Z Int.modulus).

Definition strlen_C (m : mem) (b: block) (ofs : Z) := 
  let fix strlen_fun_C (m : mem) (b : block) (ofs : Z) (l: Z) (intrange : nat) {struct intrange} : option (Z*mem):=
      match intrange with
      | O => None (* out of int range *)
      | S n => match valid_block_b m b, Mem.load chunk m b ofs with (* checking if b is a valid reference in m, loading value from memory *)
              | left _, Some v =>
                if is_null v
                then Some (l, m) else strlen_fun_C m b (ofs + 1) (l + 1) n  
              | _, _ => None (* address not readable or b not allocates *)
              end
      end
  in strlen_fun_C m b ofs 0 INTSIZE.


(* Semantics of a C light function: *)

(* strlen C light AST *)

Definition _i : ident := 54%positive.
Definition _s : ident := 53%positive.
Definition _strlen : ident := 55%positive.

Definition f_strlen := {|
  fn_return := tuint;
  fn_callconv := cc_default;
  fn_params := ((_s, (tptr tschar)) :: nil);
  fn_vars := nil;
  fn_temps := ((_i, tuint) :: nil);
  fn_body :=
(Ssequence
  (Ssequence
    (Sset _i (Econst_int (Int.repr 0) tint))
    (Sloop
      (Sifthenelse (Ebinop One
                     (Ederef
                       (Ebinop Oadd (Etempvar _s (tptr tschar))
                         (Etempvar _i tuint) (tptr tschar)) tschar)
                     (Econst_int (Int.repr 0) tint) tint)
        Sskip
        Sbreak)
      (Sset _i
        (Ebinop Oadd (Etempvar _i tuint) (Econst_int (Int.repr 1) tint)
          tuint))))
  (Sreturn (Some (Etempvar _i tuint))))
                      |}.

(* Big step semantics *)

Require Import ClightBigstep.

Parameter v : val.
Parameter m : mem.
Parameter ge : genv.
Parameter e : env.           

Definition le : temp_env  := Maps.PTree.empty val.
Definition le' := Maps.PTree.set _s v le.
Definition le'' := Maps.PTree.set _i v le'.

Require Import Events. (* E0 is an empty trace *)
           
Definition strlen_C_exec : ClightBigstep.exec_stmt ge e le' m f_strlen.(fn_body) ((E0**E0)**E0) le'' m (Out_return (Some (v,tuint))).
Proof.
  repeat econstructor.
  - simpl. admit. (* Addition sem_add *)
  - simpl. (* Mem.load *) admit.
  - simpl.  (* Comparison  sem_cmp *)  admit.
  - simpl. (* Bool val *)  admit.
  - admit. (* loop *)
Admitted.




