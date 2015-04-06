Require Import List.
Import ListNotations.
Require Import Omega.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.


Require Import Raft.
Require Import RaftRefinementInterface.
Require Import CommonDefinitions.
Require Import CommonTheorems.
Require Import SpecLemmas.

Require Import PrefixWithinTermInterface.
Require Import LogsLeaderLogsInterface.
Require Import RefinedLogMatchingLemmasInterface.
Require Import OneLeaderLogPerTermInterface.
Require Import LeaderLogsSortedInterface.
Require Import LeaderLogsSublogInterface.
Require Import LeaderSublogInterface.
Require Import NextIndexSafetyInterface.
Require Import LeaderLogsContiguousInterface.

Section PrefixWithinTerm.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {rri : raft_refinement_interface}.
  Context {llli : logs_leaderLogs_interface}.
  Context {rlmli : refined_log_matching_lemmas_interface}.
  Context {ollpti : one_leaderLog_per_term_interface}.
  Context {llsi : leaderLogs_sorted_interface}.
  Context {llsli : leaderLogs_sublog_interface}.
  Context {lsli : leader_sublog_interface}.
  Context {nisi : nextIndex_safety_interface}.
  Context {llci : leaderLogs_contiguous_interface}.

  Definition lift_leader_sublog :
    forall net leader e h,
      refined_raft_intermediate_reachable net ->
      type (snd (nwState net leader)) = Leader ->
      In e (log (snd (nwState net h))) ->
      eTerm e = currentTerm (snd (nwState net leader)) ->
      In e (log (snd (nwState net leader))).
  Proof.
    intros. pose proof lift_prop leader_sublog_host_invariant.
    conclude_using ltac:(apply leader_sublog_invariant_invariant).
    find_apply_hyp_hyp.
    match goal with
      | H : leader_sublog_host_invariant _ |- _ =>
        specialize (H leader e h)
    end.
    repeat find_rewrite_lem deghost_spec. intuition.
  Qed.

  Lemma exists_deghosted_packet :
    forall net (p : packet (params := raft_refined_multi_params (raft_params := raft_params))),
      In p (nwPackets net) ->
      exists q,
        In q (nwPackets (deghost net)) /\ q = deghost_packet p.
  Proof.
    unfold deghost.
    simpl.
    intros.
    eexists; intuition eauto.
    apply in_map_iff. eexists; eauto.
  Qed.
  
  Definition lift_leader_sublog_nw :
    forall net leader p t leaderId prevLogIndex prevLogTerm entries leaderCommit e,    
      refined_raft_intermediate_reachable net ->
      type (snd (nwState net leader)) = Leader ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t leaderId prevLogIndex prevLogTerm
                              entries leaderCommit ->
      In e entries ->
      eTerm e = currentTerm (snd (nwState net leader)) ->
      In e (log (snd (nwState net leader))).
  Proof.
    intros.
    pose proof lift_prop leader_sublog_nw_invariant.
    conclude_using ltac:(apply leader_sublog_invariant_invariant).
    find_apply_hyp_hyp.
    find_apply_lem_hyp exists_deghosted_packet.
    match goal with
      | H : exists _, _ |- _ => destruct H as (q)
    end. break_and.
    match goal with
      | H : leader_sublog_nw_invariant _ |- _ =>
        specialize (H leader q t leaderId prevLogIndex prevLogTerm entries leaderCommit e)
    end.
    repeat find_rewrite_lem deghost_spec. subst. simpl in *.
    intuition.
  Qed.
  
  Definition append_entries_append_entries_prefix_within_term_nw net :=
    forall p t n pli plt es ci p' t' n' pli' plt' es' ci' e e',
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      In p' (nwPackets net) ->
      pBody p' = AppendEntries t' n' pli' plt' es' ci' ->
      eTerm e = eTerm e' ->
      eIndex e <= eIndex e' ->
      In e es ->
      In e' es' ->
      (In e es' \/ (eIndex e = pli' /\ eTerm e = plt') \/ (eIndex e < pli' /\ eTerm e <= plt')).

  Theorem log_log_prefix_within_term_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      log_log_prefix_within_term net.
  Proof.
    red. red. intros.
    match goal with
      | H : In ?e _,
        H' : In ?e' _ |- _ =>
        copy_eapply logs_leaderLogs_invariant H; eauto;
        copy_eapply logs_leaderLogs_invariant H'; eauto
    end.
    break_exists; intuition.
    repeat find_rewrite.
    find_eapply_lem_hyp one_leaderLog_per_term_invariant; eauto.
    conclude_using eauto. subst.
    assert (exists e'', eIndex e'' = eIndex e /\ In e'' (log (snd (nwState net h')))) by
        (eapply entries_contiguous_invariant; eauto; intuition;
         [eapply entries_gt_0_invariant; eauto|];
         eapply le_trans; eauto;
         eapply maxIndex_is_max; eauto;
         apply entries_sorted_invariant; auto).
    break_exists. intuition.
    match goal with
      | _ : removeAfterIndex ?l ?i = _ _,
        _ : In ?x ?l,
        _ : eIndex ?x = _ |- _ =>
        assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
    end.
    repeat find_rewrite. do_in_app. intuition.
    - find_apply_hyp_hyp.
      eapply entries_match_invariant; eauto; repeat find_rewrite; auto.
    - cut (e = x0); intros; subst; intuition.
      eapply uniqueIndices_elim_eq; eauto.
      + apply sorted_uniqueIndices.
        apply entries_sorted_invariant.
        auto.
      + match goal with
          | H : context [ removeAfterIndex ?l ?index ] |- In _ ?l =>
            apply removeAfterIndex_in with (i := index)
        end.
        repeat find_rewrite. apply in_app_iff; intuition.
  Qed.

  Lemma app_maxIndex_thing :
    forall l l1 l2 l2' i,
      l = l1 ++ l2 ->
      Prefix l2 l2' ->
      contiguous_range_exact_lo l i ->
      maxIndex l2' <= i ->
      l = l1.
  Proof.
    intros. subst.
    destruct l2; eauto using app_nil_r.
    simpl in *.
    break_match; intuition. subst. simpl in *.
    unfold contiguous_range_exact_lo in *.
    intuition. specialize (H0 e0). conclude_using intuition.
    omega.
  Qed.

  Lemma Prefix_nil :
    forall A l,
      Prefix (A := A) l [] ->
      l = [].
  Proof.
    intros. destruct l; simpl in *; intuition.
  Qed.

  Lemma sorted_app_1 :
    forall l1 l2,
      sorted (l1 ++ l2) ->
      sorted l1.
  Proof.
    intros. induction l1; simpl in *; intuition;
    eapply H0; intuition.
  Qed.
  
  Lemma Prefix_maxIndex :
    forall l l' e,
      sorted l' ->
      Prefix l l' ->
      In e l ->
      eIndex e <= maxIndex l'.
  Proof.
    induction l; intros; simpl in *; intuition;
    break_match; intuition; repeat subst; simpl in *; auto.
    intuition.
    eapply_prop_hyp sorted sorted; eauto.
    match goal with
      | _ : eIndex _ <= maxIndex ?l |- _ =>
        destruct l
    end.
    - simpl in *.
      find_apply_lem_hyp Prefix_nil. subst. simpl in *. intuition.
    - simpl in *.
      match goal with
        | [ H : forall _, _ = _ \/ In _ _ -> _, _ : eIndex _ <= eIndex ?e |- _ ] =>
          specialize (H e)
      end; intuition.
  Qed.

  Lemma app_maxIndex_In_l :
    forall l l' e,
      sorted (l ++ l') ->
      In e (l ++ l') ->
      maxIndex l' < eIndex e ->
      In e l.
  Proof.
    induction l; intros; simpl in *; intuition.
    - destruct l'; simpl in *; intuition; subst; intuition.
      find_apply_hyp_hyp. intuition.
    - do_in_app. intuition. right. eapply IHl; eauto.
      intuition.
  Qed.
  
  Lemma thing :
    forall l1 l2 l2' i,
      Prefix l2 l2' ->
      sorted (l1 ++ l2) ->
      contiguous_range_exact_lo (l1 ++ l2) i ->
      (l2 <> [] \/ i = maxIndex l2') ->
      contiguous_range_exact_lo l1 (maxIndex l2').
  Proof.
    intros.
    destruct l2.
    - intuition. subst. rewrite app_nil_r in *. auto.
    - match goal with H : _ \/ _ |- _ => clear H end.
      simpl in *. break_match; intuition. subst. simpl.
      eauto using contiguous_partition.
  Qed.

  Lemma Prefix_In :
    forall A (l : list A) l' x,
      Prefix l l' ->
      In x l ->
      In x l'.
  Proof.
    induction l; intros; simpl in *; intuition;
    subst; break_match; intuition; subst; intuition.
  Qed.

  Lemma sorted_term_index_lt :
    forall l e e',
      sorted l ->
      In e l ->
      In e' l ->
      eIndex e < eIndex e' ->
      eTerm e <= eTerm e'.
  Proof.
    intros.
    induction l; simpl in *; intuition; repeat subst; auto;
    find_apply_hyp_hyp; intuition.
  Qed.

  Lemma contiguous_app_prefix_2 :
    forall l l' l'' i,
      sorted (l ++ l') ->
      contiguous_range_exact_lo (l ++ l') 0 ->
      Prefix l' l'' ->
      maxIndex l'' < i <= maxIndex l ->
      exists e, eIndex e = i /\ In e l.
  Proof.
    destruct l'.
    - intros. simpl in *. rewrite app_nil_r in *.
      eapply_prop (contiguous_range_exact_lo l). omega.
    - intros. find_eapply_lem_hyp thing; eauto.
      left. intuition. congruence.
  Qed.

  Lemma contiguous_0_app :
    forall l1 l2 e,
      sorted (l1 ++ l2) ->
      contiguous_range_exact_lo (l1 ++ l2) 0 ->
      In e l1 ->
      eIndex e > maxIndex l2.
  Proof.
    induction l1; intros.
    - simpl in *. intuition.
    - rewrite <- app_comm_cons in *.
      match goal with
        | H : In _ _ |- _ => simpl in H
      end. intuition.
      + subst. simpl in *. intuition.
        destruct l2; simpl in *.
        * unfold contiguous_range_exact_lo in *. intuition.
        * match goal with
            | H : _ |- eIndex _ > eIndex ?e =>
              specialize (H e)
          end. conclude_using intuition. intuition.
      + find_apply_lem_hyp cons_contiguous_sorted; eauto.
        simpl in *. intuition.
  Qed.
      

  Definition locked_or x y :=
    x \/ y.
  
  Theorem append_entries_append_entries_prefix_within_term_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      append_entries_append_entries_prefix_within_term_nw net.
  Proof.
    red. intros.
    match goal with
      | H : context [pBody],
        H' : context [pBody] |- _ =>
        copy_eapply logs_leaderLogs_nw_invariant H; eauto;
        copy_eapply logs_leaderLogs_nw_invariant H'; eauto
    end; repeat conclude_using eauto.
    break_exists; break_and.
    repeat find_rewrite.
    match goal with
      | H : refined_raft_intermediate_reachable _ |- _ =>
        copy_apply leaderLogs_sorted_invariant H
    end.
    find_eapply_lem_hyp one_leaderLog_per_term_invariant; eauto.
    conclude_using eauto. subst.
    intuition; subst.
    - destruct (lt_eq_lt_dec (eIndex e) pli'); intuition.
      left.
      match goal with
        | H : removeAfterIndex ?l ?index = ?es ++ ?ll |- _ =>
          eapply app_maxIndex_thing in H
      end;
        [|idtac|eapply removeAfterIndex_contiguous; [eapply entries_sorted_nw_invariant; eauto|eapply entries_contiguous_nw_invariant; eauto]|idtac]; eauto.
      assert (exists e'', eIndex e'' = eIndex e /\ In e'' es') by
          (eapply entries_contiguous_nw_invariant; eauto; intuition;
       eapply le_trans; eauto;
       eapply maxIndex_is_max; eauto;
       eapply entries_sorted_nw_invariant; eauto).
      break_exists. intuition.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In ?x ?l,
                  _ : eIndex ?x = _ |- _ =>
          assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      find_apply_hyp_hyp.
      eapply entries_match_nw_1_invariant.
      Focus 5. eauto. Focus 4. eauto. all:eauto; try omega. repeat find_rewrite; auto.
    - break_exists. break_and.
      match goal with
        | H : _ \/ _ |- _ => clear H
      end.
      subst. left.
      assert (pli < eIndex e) by
          (eapply entries_contiguous_nw_invariant; [idtac|idtac|eauto|]; eauto).
      assert (maxIndex x4 < eIndex e) by omega.
      assert (eIndex x0 < eIndex e).
      eapply le_lt_trans; [|eauto].
      eapply maxIndex_is_max; eauto.
      assert (exists e'', eIndex e'' = eIndex e /\ In e'' es') by
          (eapply entries_contiguous_nw_invariant; eauto; intuition;
           eapply le_trans; eauto;
           eapply maxIndex_is_max; eauto;
           eapply entries_sorted_nw_invariant; eauto).
      break_exists. intuition.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In ?x ?l,
                  _ : eIndex ?x = _ |- _ =>
          assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat find_rewrite. do_in_app. intuition.
      + find_apply_hyp_hyp.
        eapply entries_match_nw_1_invariant.
        Focus 10. eauto. Focus 5. eauto. Focus 4. eauto. all:eauto; try omega. repeat find_rewrite; auto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; eauto.
        omega.
    - left.
      assert (0 < eIndex e) by
          (eapply entries_gt_0_nw_invariant; [|idtac|idtac|eauto]; [|idtac|eauto]; eauto).
      assert (pli < eIndex e) by
          (eapply entries_contiguous_nw_invariant; [|idtac|idtac|eauto]; [|idtac|eauto]; eauto).
      assert (exists e'', eIndex e'' = eIndex e /\ In e'' es') by
          (eapply entries_contiguous_nw_invariant; eauto; intuition;
           eapply le_trans; eauto;
           eapply maxIndex_is_max; eauto;
           eapply entries_sorted_nw_invariant; eauto).
      break_exists. intuition.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In ?x ?l,
                  _ : eIndex ?x = _ |- _ =>
          assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat find_rewrite. do_in_app. intuition.
      + find_apply_hyp_hyp.
        eapply entries_match_nw_1_invariant.
        Focus 10. eauto. Focus 5. eauto. Focus 4. eauto. all:eauto; try omega. repeat find_rewrite; auto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; eauto.
        omega.
    - break_exists. break_and.
      match goal with
        | H : _ \/ _ |- _ => clear H
      end.
      subst.
      destruct (lt_eq_lt_dec (eIndex e) pli'); intuition.
      left.
      assert (exists e'', eIndex e'' = eIndex e /\ In e'' es') by
          (eapply entries_contiguous_nw_invariant; eauto; intuition;
           eapply le_trans; eauto;
           eapply maxIndex_is_max; eauto;
           eapply entries_sorted_nw_invariant; eauto).
      break_exists. intuition.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In ?x ?l,
                  _ : eIndex ?x = _ |- _ =>
          assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat find_rewrite. do_in_app. intuition.
      + find_apply_hyp_hyp.
        eapply entries_match_nw_1_invariant.
        Focus 10. eauto. Focus 5. eauto. Focus 4. eauto. all:eauto; try omega. repeat find_rewrite; auto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; eauto.
        omega.
    - destruct (lt_eq_lt_dec (eIndex e) pli'); intuition.
      left.
      assert (exists e'', eIndex e'' = eIndex e /\ In e'' es') by
          (eapply entries_contiguous_nw_invariant; eauto; intuition;
           eapply le_trans; eauto;
           eapply maxIndex_is_max; eauto;
           eapply entries_sorted_nw_invariant; eauto).
      break_exists. intuition.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In ?x ?l,
                  _ : eIndex ?x = _ |- _ =>
          assert (In x (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat find_rewrite. do_in_app. intuition.
      + find_apply_hyp_hyp.
        eapply entries_match_nw_1_invariant.
        Focus 10. eauto. Focus 5. eauto. Focus 4. eauto. all:eauto; try omega. repeat find_rewrite; auto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; eauto.
        omega.
    - break_exists. break_and.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e ?l |- _ =>
          assert (In e (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e' ?l |- _ =>
          assert (In e' (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat match goal with
               | _ : removeAfterIndex ?es _ = ?x ++ ?y,
                 Hp : pBody _ = AppendEntries _ _ ?i _ ?es _ |- _ =>
                 try match goal with
                  | _ : sorted (x ++ y) |- _ =>
                    fail 2
                     end;
                   assert (sorted (x ++ y)) by
                     (repeat find_reverse_rewrite; eapply removeAfterIndex_sorted;
                      eapply entries_sorted_nw_invariant; try apply Hp; eauto);
                   assert (contiguous_range_exact_lo (x ++ y) i) by
                       (repeat find_reverse_rewrite;
                        eapply removeAfterIndex_contiguous;
                        [eapply entries_sorted_nw_invariant; try apply Hp; eauto|
                         eapply entries_contiguous_nw_invariant; try apply Hp; eauto])
             end.
      repeat match goal with
               | H : ?x \/ ?y |- _ =>
                 copy_eapply thing H; eauto; fold (locked_or x y) in H
             end.
      match goal with
        | H : removeAfterIndex _ _ = _ |- _ =>
          assert (forall e, In e x1 -> In e es') by (intros; eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
      end.
      match goal with
        | H : removeAfterIndex _ _ = _ |- _ =>
          assert (forall e, In e x2 -> In e es') by (intros; eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
      end.
      match goal with
        | H : removeAfterIndex _ _ = _ |- _ =>
          assert (forall e, In e x5 -> In e es) by (intros; eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
      end.
      repeat find_rewrite. repeat do_in_app. intuition.
      + subst.
        assert (exists e'', eIndex e'' = eIndex e /\ In e'' x1).
        { eapply_prop (contiguous_range_exact_lo x1). intuition.
          match goal with
            | H : contiguous_range_exact_lo ?l ?i , _ : In ?e ?l |- ?i < eIndex ?e =>
              eapply H
          end; eauto.
          eapply le_trans; eauto.
          eapply maxIndex_is_max; eauto using sorted_app_1.
        }
        break_exists. break_and.
        left.
        find_copy_apply_hyp_hyp.
        match goal with
          | H : refined_raft_intermediate_reachable _ |- _ =>
            copy_apply entries_match_nw_1_invariant H
        end.
        match goal with
          | H : entries_match_nw_1 _ |- _ =>
            eapply H with (es := es) (p := p) (p' := p')
        end. all:eauto. all:intuition.
        * eapply_prop_hyp eTerm In. congruence.
        * replace (eIndex e) with (eIndex x8).
          eapply_prop (contiguous_range_exact_lo (x1 ++ x2)); eauto. in_crush.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; [|idtac|eauto]; eauto.
        match goal with
          | H: contiguous_range_exact_lo ?l ?i, _ : In ?e ?l, _ : eIndex _ <= ?i |- _ =>
            assert (i < eIndex e) by (eapply H; eauto)
        end.
        omega.
      + assert (In e x4) by eauto using Prefix_In.
        match goal with
          | _ : removeAfterIndex ?es _ = ?l, _ : contiguous_range_exact_lo ?l ?i |-
            context [In ?e ?es] =>
            destruct (lt_eq_lt_dec (eIndex e) i); intuition
        end.
        * right. right. intuition.
          repeat find_reverse_rewrite.
          match goal with
            | _ : In (_, ?ll) (leaderLogs _) |- _ =>
              eapply sorted_term_index_lt with (l := ll)
          end; eauto.
        * match goal with
            | _ : eIndex ?e = eIndex ?x, _ : In (_, ?ll) (leaderLogs _) |- _ =>
              assert (e = x); subst; repeat find_rewrite; intuition;
              eapply uniqueIndices_elim_eq with (xs := ll); eauto using sorted_uniqueIndices
          end.
        * {
            left.
            repeat match goal with
                     | H : contiguous_range_exact_lo _ _ |- _ =>
                       eapply contiguous_app in H; eauto; [idtac]
                   end.
            match goal with
              | _ : eIndex ?x < eIndex ?e , H : locked_or _ (eIndex ?x = _) |- _ =>
                unfold locked_or in H
            end. intuition.
            - match goal with
                | _ : ?x = [] -> False, _ : Prefix ?x ?ll |- In ?e _ =>
                  cut (In e x); eauto;
                  eapply prefix_contiguous; eauto
              end.
            - exfalso. repeat find_rewrite.
              match goal with
                | H : In ?e ?l, _ : maxIndex ?l < eIndex ?e |- _ =>
                  eapply maxIndex_is_max in H
              end; eauto; omega.
          }
      + match goal with
          | H : In ?e ?l, H' : In ?e' ?l', Hp : Prefix ?l _, Hp' : Prefix ?l' _ |- _ =>
            copy_eapply Prefix_In H; try apply Hp; eauto;
            copy_eapply Prefix_In H'; try apply Hp'; eauto
        end.
        match goal with
          | _ : removeAfterIndex ?es _ = ?l, _ : contiguous_range_exact_lo ?l ?i |-
            context [In ?e ?es] =>
            destruct (lt_eq_lt_dec (eIndex e) i); intuition
        end.
        * right. right. intuition.
          repeat find_reverse_rewrite.
          match goal with
            | _ : In (_, ?ll) (leaderLogs _) |- _ =>
              eapply sorted_term_index_lt with (l := ll)
          end; eauto.
        * match goal with
            | _ : eIndex ?e = eIndex ?x, _ : In (_, ?ll) (leaderLogs _) |- _ =>
              assert (e = x); subst; repeat find_rewrite; intuition;
              eapply uniqueIndices_elim_eq with (xs := ll); eauto using sorted_uniqueIndices
          end.
        * left.
          repeat match goal with
                     | H : contiguous_range_exact_lo _ _ |- _ =>
                       eapply contiguous_app in H; eauto; [idtac]
                 end.
          match goal with
            | _ : Prefix ?x ?ll |- In ?e _ =>
              cut (In e x); eauto;
              eapply prefix_contiguous; solve [eauto]
          end.
    - left.
      break_exists.
      break_and.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e ?l |- _ =>
          assert (In e (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e' ?l |- _ =>
          assert (In e' (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat match goal with
               | _ : removeAfterIndex ?es _ = ?x ++ ?y,
                 Hp : pBody _ = AppendEntries _ _ ?i _ ?es _ |- _ =>
                 try match goal with
                  | _ : sorted (x ++ y) |- _ =>
                    fail 2
                     end;
                   assert (sorted (x ++ y)) by
                     (repeat find_reverse_rewrite; eapply removeAfterIndex_sorted;
                      eapply entries_sorted_nw_invariant; try apply Hp; eauto);
                   assert (contiguous_range_exact_lo (x ++ y) i) by
                       (repeat find_reverse_rewrite;
                        eapply removeAfterIndex_contiguous;
                        [eapply entries_sorted_nw_invariant; try apply Hp; eauto|
                         eapply entries_contiguous_nw_invariant; try apply Hp; eauto])
             end.
      repeat find_rewrite.
      repeat match goal with
               | H : ?x \/ ?y |- _ =>
                 copy_eapply thing H; eauto; fold (locked_or x y) in H
             end.
      repeat do_in_app. intuition.
      + subst.
        match goal with
          | _ : In e' ?x, _ : sorted (?x ++ _), H : contiguous_range_exact_lo ?x' _, _ : In e ?x'
            |- _ =>
            assert (exists e'', eIndex e'' = eIndex e /\ In e'' x) by
                (eapply contiguous_app_prefix_2; eauto;
                 intuition; [eapply H; eauto|eapply le_trans; eauto; eapply maxIndex_is_max; eauto using sorted_app_1])
        end.
        break_exists. intuition.
        match goal with
          | H : refined_raft_intermediate_reachable _ |- _ =>
            copy_apply entries_match_nw_1_invariant H
        end.
        match goal with
          | He : eIndex ?x = eIndex e, H : removeAfterIndex _ _ = _ |- _ =>
            symmetry in He;
            assert (In x es') by (eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
        end.
        repeat find_apply_hyp_hyp.
        match goal with
          | H : entries_match_nw_1 _ |- _ =>
            eapply H with (es := es) (p := p) (p' := p')
        end. Focus 7. eauto. all:repeat find_rewrite. all:eauto. intuition.
        eapply entries_gt_0_nw_invariant; eauto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; [|idtac|eauto]; eauto.
        match goal with
          | H: contiguous_range_exact_lo ?l ?i, _ : In ?e ?l, _ : eIndex _ <= ?i |- _ =>
            assert (i < eIndex e) by (eapply H; eauto)
        end.
        omega.
      + match goal with
          | H : removeAfterIndex _ _ = _ |- _ =>
            eapply removeAfterIndex_in; rewrite H; apply in_app_iff; [idtac]
        end. eauto using Prefix_In.
      + match goal with
          | H : removeAfterIndex _ _ = _ |- _ =>
            eapply removeAfterIndex_in; rewrite H; apply in_app_iff; [idtac]
        end. eauto using Prefix_In.
    - break_exists.
      break_and.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e ?l |- _ =>
          assert (In e (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e' ?l |- _ =>
          assert (In e' (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. subst.
      repeat match goal with
               | _ : removeAfterIndex ?es _ = ?x ++ ?y,
                 Hp : pBody _ = AppendEntries _ _ ?i _ ?es _ |- _ =>
                 try match goal with
                  | _ : sorted (x ++ y) |- _ =>
                    fail 2
                     end;
                   assert (sorted (x ++ y)) by
                     (repeat find_reverse_rewrite; eapply removeAfterIndex_sorted;
                      eapply entries_sorted_nw_invariant; try apply Hp; eauto);
                   assert (contiguous_range_exact_lo (x ++ y) i) by
                       (repeat find_reverse_rewrite;
                        eapply removeAfterIndex_contiguous;
                        [eapply entries_sorted_nw_invariant; try apply Hp; eauto|
                         eapply entries_contiguous_nw_invariant; try apply Hp; eauto])
             end.
      repeat find_rewrite.
      repeat match goal with
               | H : ?x \/ ?y |- _ =>
                 copy_eapply thing H; eauto; fold (locked_or x y) in H
             end.
      repeat do_in_app. intuition.
      + left.
        assert (exists e'', eIndex e'' = eIndex e /\ In e'' x1).
        { eapply_prop (contiguous_range_exact_lo x1). intuition.
          - eapply contiguous_0_app; eauto.
          - eapply le_trans; eauto.
            eapply maxIndex_is_max; eauto using sorted_app_1.
        }
        break_exists. intuition.
        match goal with
          | H : refined_raft_intermediate_reachable _ |- _ =>
            copy_apply entries_match_nw_1_invariant H
        end.
        match goal with
          | He : eIndex ?x = eIndex e, H : removeAfterIndex _ _ = _ |- _ =>
            symmetry in He;
            assert (In x es') by (eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
        end.
        repeat find_apply_hyp_hyp.
        match goal with
          | H : entries_match_nw_1 _ |- _ =>
            eapply H with (es := es) (p := p) (p' := p')
        end. Focus 7. eauto. all:repeat find_rewrite. all:eauto. intuition.
        eapply entries_contiguous_nw_invariant; eauto.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; [|idtac|eauto]; eauto.
        find_eapply_lem_hyp contiguous_0_app; eauto. omega.
      + match goal with
          | _ : removeAfterIndex ?es _ = ?l, _ : contiguous_range_exact_lo ?l ?i |-
            context [In ?e ?es] =>
            destruct (lt_eq_lt_dec (eIndex e) i); intuition
        end.
        * right. right. intuition.
          repeat find_reverse_rewrite.
          match goal with
            | _ : In (_, ?ll) (leaderLogs _) |- _ =>
              eapply sorted_term_index_lt with (l := ll)
          end; eauto.
        * match goal with
            | _ : eIndex ?e = eIndex ?x, _ : In (_, ?ll) (leaderLogs _) |- _ =>
              assert (e = x); subst; repeat find_rewrite; intuition;
              eapply uniqueIndices_elim_eq with (xs := ll); eauto using sorted_uniqueIndices
          end.
        * {
            left.
            repeat match goal with
                     | H : contiguous_range_exact_lo _ _ |- _ =>
                       eapply contiguous_app in H; eauto; [idtac]
                   end.
            match goal with
              | _ : eIndex ?x < eIndex ?e , H : locked_or _ (eIndex ?x = _) |- _ =>
                unfold locked_or in H
            end. intuition.
            - match goal with
                | _ : ?x = [] -> False, _ : Prefix ?x ?ll |- In ?e _ =>
                  assert (In e x) by (eapply prefix_contiguous; eauto)
              end.
              match goal with
                | H : removeAfterIndex _ _ = _ |- _ =>
                  eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition
              end.
            - exfalso. repeat find_rewrite.
              match goal with
                | H : In ?e ?l, _ : maxIndex ?l < eIndex ?e |- _ =>
                  eapply maxIndex_is_max in H
              end; eauto; omega.
          }
      + match goal with
          | H : In ?e ?l, H' : In ?e' ?l', Hp : Prefix ?l _, Hp' : Prefix ?l' _ |- _ =>
            copy_eapply Prefix_In H; try apply Hp; eauto;
            copy_eapply Prefix_In H'; try apply Hp'; eauto
        end.
        match goal with
          | _ : removeAfterIndex ?es _ = ?l, _ : contiguous_range_exact_lo ?l ?i |-
            context [In ?e ?es] =>
            destruct (lt_eq_lt_dec (eIndex e) i); intuition
        end.
        * right. right. intuition.
          repeat find_reverse_rewrite.
          match goal with
            | _ : In (_, ?ll) (leaderLogs _) |- _ =>
              eapply sorted_term_index_lt with (l := ll)
          end; eauto.
        * match goal with
            | _ : eIndex ?e = eIndex ?x, _ : In (_, ?ll) (leaderLogs _) |- _ =>
              assert (e = x); subst; repeat find_rewrite; intuition;
              eapply uniqueIndices_elim_eq with (xs := ll); eauto using sorted_uniqueIndices
          end.
        * left.
          repeat match goal with
                     | H : contiguous_range_exact_lo _ _ |- _ =>
                       eapply contiguous_app in H; eauto; [idtac]
                 end.
          match goal with
            |  _ : Prefix ?x ?ll |- In ?e _ =>
               assert (In e x) by (eapply prefix_contiguous; eauto)
          end.
          match goal with
            | H : removeAfterIndex _ _ = _ |- _ =>
              eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition
          end.
    - left.
      repeat match goal with
               | _ : removeAfterIndex ?es _ = ?x ++ ?y,
                 Hp : pBody _ = AppendEntries _ _ ?i _ ?es _ |- _ =>
                 try match goal with
                  | _ : sorted (x ++ y) |- _ =>
                    fail 2
                     end;
                   assert (sorted (x ++ y)) by
                     (repeat find_reverse_rewrite; eapply removeAfterIndex_sorted;
                      eapply entries_sorted_nw_invariant; try apply Hp; eauto);
                   assert (contiguous_range_exact_lo (x ++ y) i) by
                       (repeat find_reverse_rewrite;
                        eapply removeAfterIndex_contiguous;
                        [eapply entries_sorted_nw_invariant; try apply Hp; eauto|
                         eapply entries_contiguous_nw_invariant; try apply Hp; eauto])
             end.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e ?l |- _ =>
          assert (In e (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end.
      match goal with
        | _ : removeAfterIndex ?l ?i = _,
              _ : In e' ?l |- _ =>
          assert (In e' (removeAfterIndex l i)) by (apply removeAfterIndex_le_In; eauto; omega)
      end. repeat find_rewrite. repeat do_in_app. intuition.
      + match goal with
          | H : In e _ |- _ =>
            copy_eapply contiguous_0_app H; eauto; [idtac]
        end.
        match goal with
          | _ : In e' ?l, H : contiguous_range_exact_lo (?l ++ _) 0 |- _ =>
            eapply contiguous_app_prefix_2 with (i := eIndex e) in H
        end; eauto; intuition;
        [|eapply le_trans; eauto; eapply maxIndex_is_max; eauto using sorted_app_1]; [idtac].
        break_exists. intuition.
        match goal with
          | H : refined_raft_intermediate_reachable _ |- _ =>
            copy_apply entries_match_nw_1_invariant H
        end.
        match goal with
          | He : eIndex ?x = eIndex e, H : removeAfterIndex _ _ = _ |- _ =>
            symmetry in He;
            assert (In x es') by (eapply removeAfterIndex_in; rewrite H; apply in_app_iff; intuition)
        end.
        repeat find_apply_hyp_hyp.
        match goal with
          | H : entries_match_nw_1 _ |- _ =>
            eapply H with (es := es) (p := p) (p' := p')
        end. Focus 7. eauto. all:repeat find_rewrite. all:eauto. intuition.
      + exfalso.
        find_eapply_lem_hyp Prefix_maxIndex; [|idtac|eauto]; eauto.
        find_eapply_lem_hyp contiguous_0_app; eauto. omega.
      + match goal with
          | H : removeAfterIndex _ _ = _ |- _ =>
            eapply removeAfterIndex_in; rewrite H; apply in_app_iff; [idtac]
        end. eauto using Prefix_In.
      + match goal with
          | H : removeAfterIndex _ _ = _ |- _ =>
            eapply removeAfterIndex_in; rewrite H; apply in_app_iff; [idtac]
        end. eauto using Prefix_In.
  Qed.
  
  Definition log_leaderLogs_prefix_within_term net :=
    forall h t ll leader,
      In (t, ll) (leaderLogs (fst (nwState net leader))) ->
      prefix_within_term (log (snd (nwState net h))) ll.

  Definition allEntries_log_prefix_within_term net :=
    forall h h',
      prefix_within_term (map snd (allEntries (fst (nwState net h)))) (log (snd (nwState net h'))).

  Definition allEntries_append_entries_prefix_within_term_nw net :=
    forall p t n pli plt es ci h e e',
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      eTerm e = eTerm e' ->
      eIndex e <= eIndex e' ->
      In e (map snd (allEntries (fst (nwState net h)))) ->
      In e' es ->
      (In e es \/ (eIndex e = pli /\ eTerm e = plt) \/ (eIndex e < pli /\ eTerm e <= plt)).

  Definition append_entries_leaderLogs_prefix_within_term net :=
    forall p t n pli plt es ci h t' ll,
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      In (t', ll) (leaderLogs (fst (nwState net h))) ->
      prefix_within_term es ll.

  Definition append_entries_log_prefix_within_term net :=
    forall p t n pli plt es ci h,
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      prefix_within_term es (log (snd (nwState net h))).
  
  Definition prefix_within_term_inductive net :=
    allEntries_leaderLogs_prefix_within_term net /\
    log_leaderLogs_prefix_within_term net /\
    allEntries_log_prefix_within_term net /\
    allEntries_append_entries_prefix_within_term_nw net /\
    append_entries_leaderLogs_prefix_within_term net /\
    append_entries_log_prefix_within_term net.

  Lemma findGtIndex_prefix_within_term :
    forall l1 l2 i,
      prefix_within_term l1 l2 ->
      prefix_within_term (findGtIndex l1 i) l2.
  Proof.
    unfold prefix_within_term. intros.
    find_apply_lem_hyp findGtIndex_in. eauto.
  Qed.

  Lemma update_elections_data_client_request_leaderLogs :
    forall h st client id c,
      leaderLogs (update_elections_data_client_request h st client id c) =
      leaderLogs (fst st).
  Proof.
    unfold update_elections_data_client_request in *.
    intros. repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma update_elections_data_timeout_leaderLogs :
    forall h st,
      leaderLogs (update_elections_data_timeout h st) =
      leaderLogs (fst st).
  Proof.
    unfold update_elections_data_timeout.
    intros.
    repeat break_match; simpl in *; auto.
  Qed.

  Lemma update_elections_data_appendEntries_leaderLogs :
    forall h st t h' pli plt es ci,
      leaderLogs (update_elections_data_appendEntries h st t h' pli plt es ci) =
      leaderLogs (fst st).
  Proof.
    intros.
    unfold update_elections_data_appendEntries.
    repeat break_match; subst; simpl in *; auto.
  Qed.
  
  Lemma update_elections_data_requestVote_leaderLogs :
    forall h h' t lli llt st,
      leaderLogs (update_elections_data_requestVote h h' t h' lli llt st) =
      leaderLogs (fst st).
  Proof.
    unfold update_elections_data_requestVote.
    intros.
    repeat break_match; auto.
  Qed.

  Lemma update_elections_data_requestVoteReply_leaderLogs :
    forall h h' t  st t' ll' r,
      In (t', ll') (leaderLogs (fst st)) ->
      In (t', ll') (leaderLogs (update_elections_data_requestVoteReply h h' t r st)).
  Proof.
    unfold update_elections_data_requestVoteReply.
    intros.
    repeat break_match; auto.
    simpl in *. intuition.
  Qed.
  

  Lemma handleAppendEntriesReply_entries :
    forall h st t h' pli plt es ci st' t' es',
      handleAppendEntries h st t h' pli plt es ci =
      (st', AppendEntriesReply t' es' true) ->
      es' = es.
  Proof.
    intros. unfold handleAppendEntries in *.
    repeat break_match; find_inversion; congruence.
  Qed.
  
  Lemma update_elections_data_appendEntries_allEntries :
    forall h st t h' pli plt es ci e,
      In e (map snd (allEntries (update_elections_data_appendEntries h st t h' pli plt es ci))) ->
      In e (map snd (allEntries (fst st))) \/ In e es.
  Proof.
    intros.
    unfold update_elections_data_appendEntries in *.
    repeat break_match; subst; simpl in *; auto.
    find_apply_lem_hyp handleAppendEntriesReply_entries. subst.
    do_in_map. do_in_app. subst. intuition.
    - do_in_map. subst. simpl in *. auto.
    - left. apply in_map_iff. eexists; eauto.
  Qed.

  Lemma update_elections_data_clientRequest_allEntries_new :
    forall h st client id c e,
      In e (map snd (allEntries (update_elections_data_client_request h st client id c))) ->
      In e (map snd (allEntries (fst st))) \/
      (eIndex e = S (maxIndex (log (snd st)))
       /\ eTerm e = currentTerm (snd st)
       /\ type (snd st) = Leader).
  Proof.
    intros.
    unfold update_elections_data_client_request in *.
    repeat break_match; subst; simpl in *; auto. intuition. subst.
    do_bool. find_apply_lem_hyp handleClientRequest_log.
    intuition.
    - match goal with
        | H : log _ = log (snd _) |- _ => symmetry in H
      end. repeat find_rewrite. simpl in *. omega.
    - break_exists. intuition. repeat find_rewrite.
      find_inversion. intuition.
  Qed.

  Lemma update_elections_data_clientRequest_allEntries_old :
    forall h st client id c e,
      In e (map snd (allEntries (fst st))) ->
      In e (map snd (allEntries (update_elections_data_client_request h st client id c))).
  Proof.
    intros.
    unfold update_elections_data_client_request in *.
    repeat break_match; subst; simpl in *; auto. 
  Qed.
  
  Ltac update_destruct :=
    match goal with
      | [ |- context [ update _ ?y _ ?x ] ] => destruct (name_eq_dec y x)
    end.

  Ltac update_destruct_hyp :=
    match goal with
      | [ _ : context [ update _ ?y _ ?x ] |- _ ] => destruct (name_eq_dec y x)
    end.

  Ltac destruct_update :=
    repeat (first [update_destruct_hyp|update_destruct]; subst; rewrite_update).

  Lemma prefix_within_term_union :
    forall l1 l1' l1'' l2,
      prefix_within_term l1' l2 ->
      prefix_within_term l1'' l2 ->
      (forall e, In e l1 -> In e l1' \/ In e l1'') ->
      prefix_within_term l1 l2.
  Proof.
    intros.
    unfold prefix_within_term in *.
    intros.
    find_apply_hyp_hyp. intuition; eauto.
  Qed.

  Lemma allEntries_log_matching :
    forall net e e' h h',
      refined_raft_intermediate_reachable net ->
      In e (log (snd (nwState net h))) ->
      In e' (map snd (allEntries (fst (nwState net h')))) ->
      eTerm e = eTerm e' ->
      eIndex e = eIndex e' ->
      e = e'.
  Admitted.

  Lemma terms_ge_prevTerm :
    forall net p t n pli plt es ci e,
      refined_raft_intermediate_reachable net ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      In e es ->
      eTerm e >= plt.
  Admitted.

  Lemma removeAfterIndex_maxTerm_in :
    forall e l,
      sorted l ->
      In e l ->
      maxTerm (removeAfterIndex l (eIndex e)) = eTerm e.
  Proof.
    induction l; intros; simpl in *; intuition.
    - subst. break_if; eauto.
      do_bool; omega.
    - break_if; eauto. do_bool.
      specialize (H1 e); intuition. omega.
  Qed.
  
  Lemma prefix_within_term_inductive_append_entries :
    refined_raft_net_invariant_append_entries prefix_within_term_inductive.
  Proof.
    red. unfold prefix_within_term_inductive. intuition.
    - unfold allEntries_leaderLogs_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_appendEntries_leaderLogs; eauto;
      solve [
          eapply prefix_within_term_union;
          [|idtac|eauto using update_elections_data_appendEntries_allEntries]; eauto].
    - unfold log_leaderLogs_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_appendEntries_leaderLogs; eauto;
      find_apply_lem_hyp handleAppendEntries_log; intuition;
      repeat find_rewrite; eauto;
      match goal with
        | |- context [?es ++ removeAfterIndex ?l _] =>
          eapply prefix_within_term_union with (l1' := es) (l1'' := l)
      end; eauto;
      intros;
      do_in_app; intuition; eauto using removeAfterIndex_in.
    - unfold allEntries_log_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_appendEntries_leaderLogs; eauto;
      find_apply_lem_hyp handleAppendEntries_log; intuition; subst; repeat find_rewrite;
      try solve [
            eapply prefix_within_term_union;
            [|idtac|eauto using update_elections_data_appendEntries_allEntries]; eauto].
      Unshelve. all:eauto.
      + unfold prefix_within_term, allEntries_append_entries_prefix_within_term_nw in *.
        intros.
        find_apply_lem_hyp update_elections_data_appendEntries_allEntries. intuition.
        eapply_prop_hyp pBody pBody; eauto. intuition; try omega.
        find_apply_lem_hyp allEntries_gt_0_invariant; eauto. omega.
      + unfold prefix_within_term, allEntries_append_entries_prefix_within_term_nw in *.
        intros.
        find_apply_lem_hyp update_elections_data_appendEntries_allEntries. intuition.
        do_in_app. intuition.
        * {
            copy_eapply_prop_hyp pBody pBody; eauto. intuition.
            - subst. apply in_app_iff. right.
              apply removeAfterIndex_le_In; auto.
              break_exists. intuition.
              assert (x = e) by eauto using allEntries_log_matching.
              subst. auto.
            - break_exists. intuition. subst.
              (* use the fact that the lists are sorted to prove eTerm e = eTerm x,
                 then use allEntries_log_pwt *)
              match goal with
                | _ : eIndex ?e < eIndex ?x |- _ =>
                  destruct (lt_eq_lt_dec (eTerm e) (eTerm x))
              end; intuition; try omega.
              + exfalso.
                pose proof terms_ge_prevTerm.
                eapply_prop_hyp eTerm pBody; eauto. omega.
              + apply in_app_iff. right.
                apply removeAfterIndex_le_In; [omega|].
                eapply_prop allEntries_log_prefix_within_term; eauto; omega.
          }
        * find_copy_apply_lem_hyp removeAfterIndex_in;
          find_apply_lem_hyp removeAfterIndex_In_le; [|eapply entries_sorted_invariant; eauto].
          apply in_app_iff; right. apply removeAfterIndex_le_In; eauto; try omega.
          eapply_prop allEntries_log_prefix_within_term; eauto.
      + unfold prefix_within_term, allEntries_append_entries_prefix_within_term_nw in *.
        intros.
        eapply_prop_hyp pBody pBody; eauto. intuition; try omega.
        find_apply_lem_hyp allEntries_gt_0_invariant; eauto. omega.
      + unfold prefix_within_term, allEntries_append_entries_prefix_within_term_nw in *.
        intros.
        do_in_app. intuition.
        * {
            copy_eapply_prop_hyp pBody pBody; eauto. intuition.
            - subst. apply in_app_iff. right.
              apply removeAfterIndex_le_In; auto.
              break_exists. intuition.
              assert (x = e) by eauto using allEntries_log_matching.
              subst. auto.
            - break_exists. intuition. subst.
              (* use the fact that the lists are sorted to prove eTerm e = eTerm x,
                 then use allEntries_log_pwt *)
              match goal with
                | _ : eIndex ?e < eIndex ?x |- _ =>
                  destruct (lt_eq_lt_dec (eTerm e) (eTerm x))
              end; intuition; try omega.
              + exfalso.
                pose proof terms_ge_prevTerm.
                eapply_prop_hyp eTerm pBody; eauto. omega.
              + apply in_app_iff. right.
                apply removeAfterIndex_le_In; [omega|].
                eapply_prop allEntries_log_prefix_within_term; eauto; omega.
          }
        * find_copy_apply_lem_hyp removeAfterIndex_in;
          find_apply_lem_hyp removeAfterIndex_In_le; [|eapply entries_sorted_invariant; eauto].
          apply in_app_iff; right. apply removeAfterIndex_le_In; eauto; try omega.
          eapply_prop allEntries_log_prefix_within_term; eauto.
    - (* nw nw invariant *)
      unfold allEntries_append_entries_prefix_within_term_nw. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_appendEntries_leaderLogs; eauto.
      + find_apply_lem_hyp update_elections_data_appendEntries_allEntries.
        intuition.
        * eapply_prop_hyp allEntries_append_entries_prefix_within_term_nw In;
          try eapply H13; eauto; repeat find_rewrite; intuition.
          find_apply_hyp_hyp. intuition; [in_crush|].
          subst. simpl in *. subst.
          unfold handleAppendEntries in *. repeat break_match; find_inversion; congruence.
        * 
          find_eapply_lem_hyp append_entries_append_entries_prefix_within_term_invariant.
          conclude_using eauto. find_rewrite.
          eapply H0.
          Focus 5. eauto.
          all:eauto.
          find_apply_hyp_hyp. intuition; [find_rewrite; in_crush|].
          repeat (subst; simpl in *).
          unfold handleAppendEntries in *; repeat break_match; find_inversion; congruence.
      + find_apply_hyp_hyp. intuition.
        * copy_eapply_prop_hyp allEntries_append_entries_prefix_within_term_nw pBody;
          [|repeat find_rewrite; in_crush].
          repeat conclude_using eauto. repeat find_rewrite. intuition.
        * exfalso.
          subst. simpl in *. subst.
          unfold handleAppendEntries in *; repeat break_match; find_inversion; congruence.
    - (* trivial *)
      unfold append_entries_leaderLogs_prefix_within_term. intros.
      simpl in *. find_apply_hyp_hyp. intuition;
        [|subst; simpl in *; subst;
          unfold handleAppendEntries in *; repeat break_match; find_inversion; congruence].
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_appendEntries_leaderLogs; eauto.
    - unfold append_entries_log_prefix_within_term. intros. simpl in *. subst.
      find_apply_hyp_hyp.
      intuition; [| subst; simpl in *; subst;
                    unfold handleAppendEntries in *; repeat break_match;
                    find_inversion; congruence].
      find_higher_order_rewrite.
      destruct_update; simpl in *; eauto.
      find_apply_lem_hyp handleAppendEntries_log. intuition; subst; repeat find_rewrite; eauto.
      + unfold prefix_within_term. intros.
        find_copy_apply_lem_hyp append_entries_append_entries_prefix_within_term_invariant.
        match goal with
          | H : append_entries_append_entries_prefix_within_term_nw _,
            _ : pBody ?p = AppendEntries ?t ?n ?pli ?plt ?es ?ci,
            _ : pBody ?p' = AppendEntries ?t' ?n' ?pli' ?plt' ?es' ?ci',
            _ : In ?e' ?es', _ : In ?e ?es |-
            In ?e ?es' =>
            specialize (H p t n pli plt es ci p' t' n' pli' plt' es' ci' e e')
        end.
        conclude_using ltac:(repeat find_rewrite; in_crush).
        concludes.
        conclude_using ltac:(repeat find_rewrite; in_crush).
        repeat concludes. intuition.
        * exfalso.
          match goal with
            | _ : eIndex ?e = 0 |- _ =>
              cut (eIndex e > 0); [intuition|]
          end.
          eapply entries_gt_0_nw_invariant; [|idtac|idtac|eauto]; [|idtac|eauto]; eauto.
        * omega.
      + { unfold prefix_within_term. intros.
          do_in_app. intuition.
          - find_copy_apply_lem_hyp append_entries_append_entries_prefix_within_term_invariant.
            match goal with
              | H : append_entries_append_entries_prefix_within_term_nw _,
                    _ : pBody ?p = AppendEntries ?t ?n ?pli ?plt ?es ?ci,
                        _ : pBody ?p' = AppendEntries ?t' ?n' ?pli' ?plt' ?es' ?ci',
                            _ : In ?e' ?es', _ : In ?e ?es |-
                In ?e (?es' ++ _) =>
                specialize (H p t n pli plt es ci p' t' n' pli' plt' es' ci' e e')
            end.
            conclude_using ltac:(repeat find_rewrite; in_crush).
            concludes.
            conclude_using ltac:(repeat find_rewrite; in_crush).
            repeat concludes. intuition.
            + (* use  log matching *)
              break_exists. intuition.
              subst.
              apply in_app_iff. right.
              apply removeAfterIndex_le_In; auto.
              eapply entries_match_nw_host_invariant. Focus 8. eauto.
              Focus 3. eauto. all:eauto.
            + (* contra terms_ge_prevTerm *)
              pose proof terms_ge_prevTerm.
              eapply_prop_hyp eTerm (pBody p); eauto. repeat find_rewrite.
              match goal with
                | _ : ?x >= ?y, _ : ?x <= ?y |- _ =>
                  assert (x = y) by eauto using le_antisym
              end. subst.
              break_exists. intuition.
              subst.
              apply in_app_iff. right.
              apply removeAfterIndex_le_In; auto; [omega|].
              eapply_prop append_entries_log_prefix_within_term. Focus 6. eauto.
            Focus 5. eauto. Focus 2. eauto. all:eauto; repeat find_rewrite; intuition.
          - apply in_app_iff. right.
            find_copy_apply_lem_hyp removeAfterIndex_in.
            find_apply_lem_hyp removeAfterIndex_In_le; [|eapply entries_sorted_invariant; eauto].
            eapply removeAfterIndex_le_In; [omega|].
            eapply_prop append_entries_log_prefix_within_term. Focus 6. eauto.
            Focus 5. eauto. Focus 2. eauto. all:eauto.
        }
  Qed.

  Lemma handleClientRequest_log' :
    forall h st client id c out st' ms e,
      handleClientRequest h st client id c = (out, st', ms) ->
      In e (log st') ->
      In e (log st) \/
      eIndex e = S (maxIndex (log st))
      /\ eTerm e = currentTerm st
      /\ type st = Leader.
  Proof.
    intros. find_apply_lem_hyp handleClientRequest_log.
    intuition; repeat find_rewrite; intuition.
    break_exists; intuition; repeat find_rewrite; simpl in *; intuition.
    subst. auto.
  Qed.

  Lemma allEntries_sublog :
    forall net leader e h,
      refined_raft_intermediate_reachable net ->
      type (snd (nwState net leader)) = Leader ->
      In e (map snd (allEntries (fst (nwState net h)))) ->
      eTerm e = currentTerm (snd (nwState net leader)) ->
      In e (log (snd (nwState net leader))).
  Admitted.

  Lemma prefix_within_term_inductive_client_request :
    refined_raft_net_invariant_client_request prefix_within_term_inductive.
  Proof.
    red. unfold prefix_within_term_inductive. intuition.
    - unfold allEntries_leaderLogs_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_client_request_leaderLogs; eauto.
      + unfold prefix_within_term. intros.
        find_apply_lem_hyp update_elections_data_clientRequest_allEntries_new. intuition.
        * eapply_prop allEntries_leaderLogs_prefix_within_term; eauto.
        * exfalso.
          repeat find_rewrite.
          find_eapply_lem_hyp leaderLogs_sublog_invariant; eauto.
          repeat conclude_using eauto.
          find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
          unfold ghost_data in *. simpl in *. omega.
      + unfold prefix_within_term. intros.
        find_apply_lem_hyp update_elections_data_clientRequest_allEntries_new. intuition.
        * eapply_prop allEntries_leaderLogs_prefix_within_term; eauto.
        * exfalso.
          repeat find_rewrite.
          find_eapply_lem_hyp leaderLogs_sublog_invariant; eauto.
          repeat conclude_using eauto.
          find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
          unfold ghost_data in *. simpl in *. omega.
    - unfold log_leaderLogs_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      try find_rewrite_lem update_elections_data_client_request_leaderLogs; eauto.
      + unfold prefix_within_term. intros.
        find_eapply_lem_hyp handleClientRequest_log'; eauto. intuition.
        * eapply_prop log_leaderLogs_prefix_within_term; eauto.
        * exfalso.
          repeat find_rewrite.
          find_eapply_lem_hyp leaderLogs_sublog_invariant; eauto.
          repeat conclude_using eauto.
          find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
          unfold ghost_data in *. simpl in *. omega.
      + unfold prefix_within_term. intros.
        find_eapply_lem_hyp handleClientRequest_log'; eauto. intuition.
        * eapply_prop log_leaderLogs_prefix_within_term; eauto.
        * exfalso.
          repeat find_rewrite.
          find_eapply_lem_hyp leaderLogs_sublog_invariant; eauto.
          repeat conclude_using eauto.
          find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
          unfold ghost_data in *. simpl in *. omega.
    - unfold allEntries_log_prefix_within_term. intros.
      simpl in *. subst. repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
      + unfold prefix_within_term. intros.
        match goal with
          | H : In _ (map _ _) |- _ => unfold update_elections_data_client_request in H
        end.
        repeat break_let.
        find_inversion.
        find_apply_lem_hyp handleClientRequest_log. intuition; repeat find_rewrite.
        * break_if; do_bool; try omega.
          eapply_prop allEntries_log_prefix_within_term; eauto.
        * { break_exists; intuition.
            repeat find_rewrite. simpl in *. break_if; do_bool; try omega.
            do_in_map; simpl in *; intuition; subst; simpl in *; auto.
            - right. eapply allEntries_sublog; repeat find_rewrite; eauto.
              apply in_map_iff; eauto.
            - right. eapply_prop allEntries_log_prefix_within_term; eauto.
              apply in_map_iff; eauto.
          }
      + unfold prefix_within_term. intros.
        match goal with
          | H : In _ (map _ _) |- _ => unfold update_elections_data_client_request in H
        end.
        repeat break_let.
        find_inversion.
        find_apply_lem_hyp handleClientRequest_log. intuition; repeat find_rewrite.
        * break_if; do_bool; try omega.
          eapply_prop allEntries_log_prefix_within_term; eauto.
        * { break_exists; intuition.
            repeat find_rewrite. simpl in *. break_if; do_bool; try omega.
            do_in_map; simpl in *; intuition; subst; simpl in *; auto.
            - find_eapply_lem_hyp lift_leader_sublog; repeat find_rewrite; eauto.
              find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
              unfold ghost_data in *. simpl in *. omega.
            - eapply_prop allEntries_log_prefix_within_term; eauto.
              apply in_map_iff; eauto.
          }
      + unfold prefix_within_term. intros.
        find_apply_lem_hyp handleClientRequest_log. intuition; repeat find_rewrite.
        * eapply_prop allEntries_log_prefix_within_term; eauto.
        * { break_exists; intuition. repeat find_rewrite. simpl in *. intuition.
            - subst. right.
              eapply allEntries_sublog; repeat find_rewrite; eauto.
            - right. eapply_prop allEntries_log_prefix_within_term; eauto.
          }
    - (* leadersublog_nw *)
      unfold allEntries_append_entries_prefix_within_term_nw. intros.
      simpl in *. subst.
      find_apply_hyp_hyp.
      intuition; [| do_in_map; subst; simpl in *;
                    find_eapply_lem_hyp handleClientRequest_no_append_entries; eauto;
                    intuition;
                    find_false; repeat eexists; eauto].
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
      + find_apply_lem_hyp update_elections_data_clientRequest_allEntries_new.
        intuition.
        * eapply_prop_hyp allEntries_append_entries_prefix_within_term_nw pBody; eauto.
          repeat conclude_using eauto. repeat find_rewrite. auto.
        * exfalso. find_rewrite.
          find_eapply_lem_hyp lift_leader_sublog_nw; eauto.
          find_eapply_lem_hyp maxIndex_is_max; [|eapply entries_sorted_invariant; eauto].
          unfold ghost_data in *. simpl in *. omega.
      + eapply_prop_hyp allEntries_append_entries_prefix_within_term_nw pBody; eauto.
        repeat conclude_using eauto. repeat find_rewrite. auto.
    - (* trivial *)
      unfold append_entries_leaderLogs_prefix_within_term in *. intros.
      simpl in *. subst.
      find_apply_hyp_hyp.
      intuition; [| do_in_map; subst; simpl in *;
                    find_eapply_lem_hyp handleClientRequest_no_append_entries; eauto;
                    intuition;
                    find_false; repeat eexists; eauto].
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
      find_rewrite_lem update_elections_data_client_request_leaderLogs. eauto.
    - unfold append_entries_log_prefix_within_term, prefix_within_term in *.
      intros. simpl in *. subst.
      find_apply_hyp_hyp.
      intuition; [| do_in_map; subst; simpl in *;
                    find_eapply_lem_hyp handleClientRequest_no_append_entries; eauto;
                    intuition;
                    find_false; repeat eexists; eauto].
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
      find_apply_lem_hyp handleClientRequest_log. intuition; repeat find_rewrite; eauto.
      break_exists; intuition. repeat find_rewrite. simpl in *; eauto.
      intuition; eauto. subst.
      right.
      eapply lift_leader_sublog_nw; repeat find_rewrite; eauto.
  Qed.

    Lemma doLeader_spec :
    forall st h os st' ms m t n pli plt es ci,
      doLeader st h = (os, st', ms) ->
      In m ms ->
      snd m = AppendEntries t n pli plt es ci ->
      t = currentTerm st /\
      log st' = log st /\
      type st = Leader /\
      ((pli = 0 /\ plt = 0 /\ es = findGtIndex (log st) 0) \/
       ((exists e, findAtIndex (log st) pli = Some e /\
              eTerm e = plt) /\
        es = findGtIndex (log st) pli) \/
       exists h', pred (getNextIndex st h') <> 0 /\ findAtIndex (log st) (pred (getNextIndex st h')) = None).
  Proof.
    intros. unfold doLeader, advanceCommitIndex in *.
    break_match; try solve [find_inversion; simpl in *; intuition].
    break_if; try solve [find_inversion; simpl in *; intuition].
    find_inversion. simpl. do_in_map. subst.
    simpl in *. find_inversion. intuition.
    match goal with
      | |- context [pred ?x] =>
        remember (pred x) as index
    end. break_match; simpl in *.
    - right. left. eauto.
    -  destruct index; intuition.
       right. right. exists x.
       match goal with
         | _ : S _ = pred ?x |- context [pred ?y] =>
           assert (pred x = pred y) by auto
       end.
       repeat find_rewrite. intuition.
  Qed.

  Lemma doLeader_in_entries_in_log :
     forall st h os st' ms m t n pli plt es ci e,
      doLeader st h = (os, st', ms) ->
      In m ms ->
      snd m = AppendEntries t n pli plt es ci ->
      In e es -> In e (log st).
  Proof.
  intros. unfold doLeader, advanceCommitIndex in *.
    break_match; try solve [find_inversion; simpl in *; intuition].
    break_if; try solve [find_inversion; simpl in *; intuition].
    find_inversion. do_in_map. subst. simpl in *. find_inversion.
    eauto using findGtIndex_in.
  Qed.

  Lemma lift_nextIndex_safety :
    forall net,
      refined_raft_intermediate_reachable net ->
      nextIndex_safety (deghost net).
  Proof.
    intros.
    eapply lift_prop; eauto using nextIndex_safety_invariant.
  Qed.

  Require Import Omega.
  
  Lemma nextIndex_sanity :
    forall net h h',
      refined_raft_intermediate_reachable net ->
      type (snd (nwState net h)) = Leader ->
      pred (getNextIndex (snd (nwState net h)) h') <> 0 ->
      exists e,
        findAtIndex (log (snd (nwState net h))) (pred (getNextIndex (snd (nwState net h)) h')) = Some e.
  Proof.
    intros.
    find_copy_apply_lem_hyp entries_contiguous_invariant.
    find_copy_apply_lem_hyp lift_nextIndex_safety.
    assert (pred (getNextIndex (snd (nwState net h)) h') > 0) by omega.
    unfold nextIndex_safety in *.
    match goal with
      | H : forall _ _, type _ = _ -> _ |- _ => specialize (H h h')
    end. 
    intuition.
    unfold entries_contiguous in *. specialize (H2 h).
    unfold contiguous_range_exact_lo in *. intuition.
    match goal with
      | H : forall _, _ < _ <= _ -> _ |- _ =>
        specialize (H (pred (getNextIndex (snd (nwState net h)) h')))
    end.
    unfold raft_refined_base_params in *.
    repeat find_rewrite_lem deghost_spec. intuition.
    break_exists_exists. intuition.
    find_apply_lem_hyp entries_sorted_invariant.
    apply findAtIndex_intro; eauto using sorted_uniqueIndices.
  Qed.
  
  Lemma prefix_within_term_subset :
    forall l1 l1' l2,
      prefix_within_term l1' l2 ->
      (forall e, In e l1 -> In e l1') ->
      prefix_within_term l1 l2.
  Proof.
    eauto using prefix_within_term_union.
  Qed.
  
  Lemma prefix_within_term_inductive_do_leader :
    refined_raft_net_invariant_do_leader prefix_within_term_inductive.
  Proof.
    red. unfold prefix_within_term_inductive. intros.
    match goal with
      | H : nwState ?net ?h = (?gd, ?d) |- _ =>
        replace gd with (fst (nwState net h)) in * by (rewrite H; reflexivity);
          replace d with (snd (nwState net h)) in * by (rewrite H; reflexivity);
          clear H
    end.
    intuition.
    - unfold allEntries_leaderLogs_prefix_within_term in *.
      simpl in *. intros.
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
    - unfold log_leaderLogs_prefix_within_term in *.
      simpl in *. intros.
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      erewrite doLeader_log; eauto; eauto.
    - unfold allEntries_log_prefix_within_term in *.
      simpl in *. intros.
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto;
      erewrite doLeader_log; eauto; eauto.
    - find_copy_apply_lem_hyp entries_sorted_invariant.
      unfold entries_sorted in *.
      unfold allEntries_append_entries_prefix_within_term_nw in *.
      simpl in *. intros.
      repeat find_higher_order_rewrite.
      repeat destruct_update; simpl in *; eauto.
      + find_apply_hyp_hyp.
        intuition;
          [repeat find_reverse_rewrite; eauto|].
        do_in_map. subst. simpl in *.
        find_eapply_lem_hyp doLeader_spec; eauto. intuition; subst.
        * left. find_apply_lem_hyp findGtIndex_necessary. intuition.
          apply findGtIndex_sufficient; eauto using allEntries_gt_0_invariant.
          unfold allEntries_log_prefix_within_term, prefix_within_term in *. eauto.
        * { break_exists. break_and. find_apply_lem_hyp findAtIndex_elim. break_and.
            subst. find_apply_lem_hyp findGtIndex_necessary. break_and.
            eapply_prop_hyp allEntries_log_prefix_within_term allEntries; eauto;
            conclude_using eauto.
            match goal with
              | _ : eIndex ?e <= eIndex ?e', _ : eIndex ?e' > eIndex ?x |- _ =>
                destruct (lt_eq_lt_dec (eIndex e) (eIndex x))
            end; intuition.
            - right. right. intuition.
              repeat find_reverse_rewrite.
              eapply sorted_term_index_lt; eauto.
              repeat find_rewrite. auto.
            - right. left. intuition.
              repeat find_reverse_rewrite.
              match goal with
                | |- eTerm ?e = eTerm ?x =>
                  cut (e = x); intros; subst; intuition
              end. repeat find_rewrite.
              eapply uniqueIndices_elim_eq; eauto using sorted_uniqueIndices.
            - left. apply findGtIndex_sufficient; eauto.
          }
        * break_exists. intuition.
          find_eapply_lem_hyp nextIndex_sanity; eauto. break_exists.
          unfold ghost_data in *. simpl in *. congruence.
      + find_apply_hyp_hyp.
        intuition;
          [repeat find_reverse_rewrite; eauto|].
        do_in_map. subst. simpl in *.
        find_eapply_lem_hyp doLeader_spec; eauto. intuition; subst.
        * left. find_apply_lem_hyp findGtIndex_necessary. intuition.
          apply findGtIndex_sufficient; eauto using allEntries_gt_0_invariant.
          unfold allEntries_log_prefix_within_term, prefix_within_term in *. eauto.
        * { break_exists. break_and. find_apply_lem_hyp findAtIndex_elim. break_and.
            subst. find_apply_lem_hyp findGtIndex_necessary. break_and.
            eapply_prop_hyp allEntries_log_prefix_within_term allEntries; eauto;
            conclude_using eauto.
            match goal with
              | _ : eIndex ?e <= eIndex ?e', _ : eIndex ?e' > eIndex ?x |- _ =>
                destruct (lt_eq_lt_dec (eIndex e) (eIndex x))
            end; intuition.
            - right. right. intuition.
              repeat find_reverse_rewrite.
              eapply sorted_term_index_lt; eauto.
              repeat find_rewrite. auto.
            - right. left. intuition.
              repeat find_reverse_rewrite.
              match goal with
                | |- eTerm ?e = eTerm ?x =>
                  cut (e = x); intros; subst; intuition
              end. repeat find_rewrite.
              eapply uniqueIndices_elim_eq; eauto using sorted_uniqueIndices.
            - left. apply findGtIndex_sufficient; eauto.
          }
        * break_exists. intuition.
          find_eapply_lem_hyp nextIndex_sanity; eauto. break_exists.
          unfold ghost_data in *. simpl in *. congruence.
    - unfold append_entries_leaderLogs_prefix_within_term in *.
      intros. simpl in *.
      match goal with
        | H : In ?x (leaderLogs (fst (st' ?h))) |- _ =>
          assert (In x (leaderLogs (fst (nwState net h)))) by
              (find_higher_order_rewrite;
               destruct_update; simpl in *; auto);
            clear H
      end.
      find_apply_hyp_hyp. intuition; eauto.
      do_in_map. subst. simpl in *.
      eapply prefix_within_term_subset; [eapply_prop log_leaderLogs_prefix_within_term|];
      eauto using doLeader_in_entries_in_log.
    - unfold append_entries_log_prefix_within_term in *.
      intros. simpl in *.
      match goal with
        | |- context [log (snd (st' ?h)) ] => 
          assert (log (snd (st' h)) = log (snd (nwState net h)))
                 by (find_higher_order_rewrite; destruct_update; simpl in *; auto;
                     eapply doLeader_log; eauto)
      end.
      repeat find_rewrite.
      find_apply_hyp_hyp. intuition; eauto.
      do_in_map. subst. simpl in *.
      eapply prefix_within_term_subset; [eapply log_log_prefix_within_term_invariant|];
      eauto using doLeader_in_entries_in_log.
  Qed.
  
  Instance pwti : prefix_within_term_interface.
  Admitted.
  
End PrefixWithinTerm.
