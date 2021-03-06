Require Import List.

Require Import VerdiTactics.
Require Import Net.
Require Import Raft.
Require Import RaftRefinementInterface.

Section AllEntriesLeaderLogs.

  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Definition leader_without_missing_entry net :=
    forall t e h,
      In (t, e) (allEntries (fst (nwState net h))) ->
      In e (log (snd (nwState  net h))) \/
      exists t' log' leader e',
        t' > t /\
        In (t', log') (leaderLogs (fst (nwState net leader))) /\
        ~ In e log' /\
        In (t', e') (allEntries (fst (nwState net h))).

  Definition appendEntriesRequest_exists_leaderLog net :=
    forall p t leaderId prevLogIndex prevLogTerm entries leaderCommit,
      In p (nwPackets net) ->
      pBody p = AppendEntries t leaderId prevLogIndex prevLogTerm
                              entries leaderCommit ->
      exists log,
        In (t, log) (leaderLogs (fst (nwState net (pSrc p)))).

  Definition appendEntriesRequest_leaderLog_not_in net :=
    forall p t leaderId prevLogIndex prevLogTerm entries leaderCommit log e,
      In p (nwPackets net) ->
      pBody p = AppendEntries t leaderId prevLogIndex prevLogTerm
                              entries leaderCommit ->
      eIndex e > prevLogIndex ->
      ~ In e entries ->
      In (t, log) (leaderLogs (fst (nwState net (pSrc p)))) ->
      ~ In e log.

  Definition appendEntries_leader net :=
    forall p t leaderId prevLogIndex prevLogTerm entries leaderCommit h e,
      In p (nwPackets net) ->
      pBody p = AppendEntries t leaderId prevLogIndex prevLogTerm
                              entries leaderCommit ->
      In e entries ->
      currentTerm (snd (nwState net h)) = t ->
      type (snd (nwState net h)) = Leader ->
      In e (log (snd (nwState net h))).

  Definition leaderLogs_leader net :=
    forall h,
      type (snd (nwState net h)) = Leader ->
      exists log' es,
        In (currentTerm (snd (nwState net h)), log') (leaderLogs (fst (nwState net h))) /\
        log (snd (nwState net h)) = es ++ log'.

  Definition all_entries_leader_logs net :=
    leader_without_missing_entry net /\ appendEntriesRequest_exists_leaderLog net /\
    appendEntriesRequest_leaderLog_not_in net /\ appendEntries_leader net /\
    leaderLogs_leader net.
  
  Class all_entries_leader_logs_interface : Prop :=
    {
      all_entries_leader_logs_invariant :
        forall net,
          refined_raft_intermediate_reachable net ->
          all_entries_leader_logs net
    }.
End AllEntriesLeaderLogs.
