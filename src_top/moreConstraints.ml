(*=======================================================================================*)
(*                                                                                       *)
(*                rmem executable model                                                  *)
(*                =====================                                                  *)
(*                                                                                       *)
(*  This file is:                                                                        *)
(*                                                                                       *)
(*  Copyright Shaked Flur, University of Cambridge                           2015-2017   *)
(*  Copyright Susmit Sarkar, University of St Andrews                        2014-2015   *)
(*  Copyright Robert Norton-Wright, University of Cambridge                  2016-2017   *)
(*  Copyright Jon French, University of Cambridge                                 2018   *)
(*  Copyright Christopher Pulte, University of Cambridge                    2016, 2018   *)
(*  Copyright Peter Sewell, University of Cambridge                               2014   *)
(*  Copyright Luc Maranget, INRIA, Paris, France                                  2017   *)
(*  Copyright Kathy Gray, University of Cambridge (when this work was done)       2017   *)
(*                                                                                       *)
(*  All rights reserved.                                                                 *)
(*                                                                                       *)
(*  It is part of the rmem tool, distributed under the 2-clause BSD licence in           *)
(*  LICENCE.txt.                                                                         *)
(*                                                                                       *)
(*=======================================================================================*)









module type S = sig
  type value = int64
  type address = int64
  type size = Sail_impl_base.size
  type footprint = address * size
  type register_snapshot = (Sail_impl_base.reg_base_name * int64) list
  type memory_snapshot = (footprint * Nat_big_num.num) list (* TODO: and with coherence_new? *)

  type location =
    | Loc_mem of address
    | Loc_reg of Events.thread_id * Sail_impl_base.reg_base_name

  type symbol_table = (address * string) list

  type prop = (location, value) ConstrGen.prop
  type constr = prop ConstrGen.constr

  val big_num_to_int64 : Nat_big_num.num -> int64
  val big_num_to_value : Nat_big_num.num -> value
  val sail_address_to_address : Sail_impl_base.address -> address

  val pp_atom : symbol_table -> (location, int64) ConstrGen.atom -> string

  val locations : constr -> location list
  val locations_prop : prop -> location list

  type state = 
      (Events.thread_id * register_snapshot) list 
        * memory_snapshot

  type incomplete_state = 
      ((Events.thread_id * register_snapshot) list) option
        * memory_snapshot option

  val trim_state :
      (Events.thread_id * Sail_impl_base.reg_base_name) list ->
        (Sail_impl_base.address * int) list -> state -> state
            
  val pp_state : symbol_table -> state -> string

  val pp_nvm_state : symbol_table -> memory_snapshot -> string

(* Check state *)
  val check_prop : prop -> state -> bool
  val check_filter : prop -> state -> bool
  val check_constr : constr -> state list -> bool
  val check_prop_incomplete_state : prop -> incomplete_state -> bool option
end

open ConstrGen

module Make : S =
  struct
    type value = int64
    type address = int64
    type size = Sail_impl_base.size
    type footprint = address * size
    type register_snapshot = (Sail_impl_base.reg_base_name * int64) list
    type memory_snapshot = (footprint * Nat_big_num.num) list

    type location =
      | Loc_mem of address
      | Loc_reg of Events.thread_id * Sail_impl_base.reg_base_name
            
    type prop = (location, value) ConstrGen.prop
    type constr = prop ConstrGen.constr

    let big_num_to_int64 (i: Nat_big_num.num) : int64 =
      if Nat_big_num.greater i (Nat_big_num.of_int64 Int64.max_int) then
        Nat_big_num.to_int64 (Nat_big_num.sub i (Nat_big_num.pow_int_positive 2 64))
      else
        Nat_big_num.to_int64 i

    let big_num_to_value : Nat_big_num.num -> value = big_num_to_int64

    let sail_address_to_address (a: Sail_impl_base.address) : address =
      Sail_impl_base.integer_of_address a |> big_num_to_int64



    (* translate from Sail register name to litmus register name *)
    let pp_reg r =
      let open InstructionSemantics in
      begin match !Globals.isa_model with
      | PPC ->
          if String.length r > 3 &&
            r.[0] = 'G' && r.[1] = 'P' && r.[2] = 'R'
          then "r" ^ String.sub r 3 (String.length r - 3)
          else r
      | AARCH64 Hand
      | AARCH64 Gen ->
          (*General registers currently have the same names for both models*)
          begin try
            let u = Scanf.sscanf (r ^ "$") "R%u$" (fun u -> if u < 31 then u else invalid_arg r) in
            AArch64HGenBase.pp_reg (AArch64HGenBase.Ireg (AArch64HGenBase.ireg_of_int u))
          with
          | _ -> r
          end
      | MIPS ->
         begin try
             let u = Scanf.sscanf (r ^ "$") "GPR%u$" (fun u -> if u < 32 then u else invalid_arg r) in
             MIPSHGenBase.pp_reg (MIPSHGenBase.IReg (MIPSHGenBase.int_to_ireg u))
           with
           | _ -> r
         end
      | RISCV ->
         begin try
             let u = Scanf.sscanf (r ^ "$") "x%u$" (fun u -> if u < 32 then u else invalid_arg r) in
             RISCVHGenBase.pp_reg (RISCVHGenBase.IReg (RISCVHGenBase.int_to_ireg u))
           with
           | _ -> r
         end
      | X86 ->
         r
      end

    let pp_loc symtab l =
      match l with
      | Loc_mem a -> 
          begin
            try List.assoc a symtab 
            with Not_found -> Int64.to_string a
          end
      | Loc_reg (tid, r) -> Printf.sprintf "%d:%s" tid (pp_reg r)

    let pp_val symtab v =
      try List.assoc v symtab
      with Not_found -> 
        if !Globals.print_hex
        then Printf.sprintf "0x%Lx" v 
        else Printf.sprintf "%Ld" v

    let pp_atom symtab a =
      let open ConstrGen in
      match a with 
      | LV (l, v) -> pp_loc symtab l ^ "=" ^ pp_val symtab v
      | LL (l1, l2) -> pp_loc symtab l1 ^"=" ^ pp_loc symtab l2
          
    let locations_atom a r =
      let open ConstrGen in
      match a with
      | LV (loc,_) -> loc :: r
      | LL (loc1,loc2) -> loc1 :: loc2 :: r

    let locations (c:constr) =
      let locs = fold_constr locations_atom c [] in
      locs
    and locations_prop (p:prop) =
      let locs = fold_prop locations_atom p [] in
      locs
      

    type state = 
        (Events.thread_id * register_snapshot) list 
          * memory_snapshot



    type incomplete_state = 
        ((Events.thread_id * register_snapshot) list) option
          * memory_snapshot option

    let trim_state kregs _ (regs,mem) =
      let regs =
        List.fold_right
          (fun (tid,rs) k ->
            let rs =
              List.filter
                (fun (r,v) -> List.mem (tid,r) kregs)
                rs in
            match rs with
            | [] -> k
            | _  -> (tid,rs)::k)
          regs [] in
      regs,mem
        
    type symbol_table = (address * string) list

    let pp_state symtab (regs, mem) =
      let reg_strings =
        List.concat
          (List.map 
             (fun (tid, rs) ->
               List.map 
                 (fun (r, v) ->
                   let r' = (pp_reg r) in
                   let v' = (pp_val symtab v) in
                   Printf.sprintf "%d:%s=%s; " tid r' v'
                 ) rs)
             regs
          )
      in
      let mem_strings =
        List.map
          (fun ((a,_), mv) ->
            let astr = try List.assoc a symtab with Not_found -> Int64.to_string a in
            let mvstr =
              if Nat_big_num.less_equal mv (Nat_big_num.of_int64 Int64.max_int) &&
                  Nat_big_num.less_equal (Nat_big_num.of_int64 Int64.min_int) mv
              then
                Nat_big_num.to_int64 mv
                |> pp_val symtab
              else if !Globals.print_hex then
                "0x" ^ Misc_extra.big_num_to_hex_string mv
              else
                Nat_big_num.to_string mv
            in
            Printf.sprintf "%s=%s; " astr mvstr)
          mem
      in
      String.concat "" (reg_strings @ mem_strings)

    let pp_nvm_state symtab mem =
      let mem_strings =
        List.map
          (fun ((a,_), mv) ->
            let astr = try List.assoc a symtab with Not_found -> Int64.to_string a in
            let mvstr =
              if Nat_big_num.less_equal mv (Nat_big_num.of_int64 Int64.max_int) &&
                  Nat_big_num.less_equal (Nat_big_num.of_int64 Int64.min_int) mv
              then
                Nat_big_num.to_int64 mv
                |> pp_val symtab
              else if !Globals.print_hex then
                "0x" ^ Misc_extra.big_num_to_hex_string mv
              else
                Nat_big_num.to_string mv
            in
            Printf.sprintf "%s=%s; " astr mvstr)
          mem
      in
      String.concat "" mem_strings



    let look_in_memstate (mem : memory_snapshot) (a : address) = 
      (* should we have a identity coercion on mv to do endianness etc? *)
      try snd (List.find (fun ((a', _), _) -> a' = a) mem) with
            | Not_found -> Nat_big_num.zero

    let look_in_regstate tid (rsts : (Events.thread_id * register_snapshot) list) r = 
      try
        let rst = List.assoc tid rsts in
        Nat_big_num.of_int64 (List.assoc r rst)
      with
      | Not_found -> Nat_big_num.zero
  
    let look_in_state (state : state) l : Nat_big_num.num =
      begin match l with
      | Loc_mem a -> look_in_memstate (snd state) a
      | Loc_reg (tid, r) -> look_in_regstate tid (fst state) r
      end

    let rec check_prop p state = match p with
    | Atom (LV (l,v)) ->
        let v = Nat_big_num.of_int64 v in
        let v' = look_in_state state l in
        Nat_big_num.equal v v'
    | Atom (LL (l1,l2)) ->
        let v1 = look_in_state state l1 in
        let v2 = look_in_state state l2 in
        Nat_big_num.equal v1 v2
    | Not p -> not (check_prop p state)
    | And ps -> List.for_all (fun p -> check_prop p state) ps
    | Or ps -> List.exists (fun p -> check_prop p state) ps
    | Implies (p1, p2) -> 
	if check_prop p1 state then check_prop p2 state else true


    let check_filter p s = check_prop p s
          
    let check_constr c states = match c with
    | ForallStates p -> List.for_all (fun s -> check_prop p s) states
    | ExistsState p -> List.exists (fun s -> check_prop p s) states
    | NotExistsState p ->
        not (List.exists (fun s -> check_prop p s) states)	      



    let look_in_incomplete_state state l : Nat_big_num.num option =
      begin match l, state with
      | (Loc_mem a), (_, Some mem) -> Some (look_in_memstate mem a)
      | (Loc_reg (tid, r)), (Some rsts, _) -> Some (look_in_regstate tid rsts r)
      | _ -> None
      end

    let rec check_prop_incomplete_state p state = match p with
    | Atom (LV (l,v)) ->
       begin match look_in_incomplete_state state l with
       | Some v' ->
          let v = Nat_big_num.of_int64 v in
          Some (Nat_big_num.equal v v')
       | None -> None
       end
    | Atom (LL (l1,l2)) ->
       let v1 = look_in_incomplete_state state l1 in
       let v2 = look_in_incomplete_state state l2 in
       begin match v1, v2 with
       | Some v1, Some v2 ->
          Some (Nat_big_num.equal v1 v2)
       | _ -> None
       end
    | Not p -> 
       begin match check_prop_incomplete_state p state with
       | Some false -> Some true
       | Some true -> Some false
       | None -> None
       end
    | And ps -> 
       List.fold_left
         (fun acc p ->
           match acc, check_prop_incomplete_state p state with
           | Some false, _ | _, Some false -> Some false
           | Some true, Some true -> Some true
           | _, _ -> None
         )
         (Some true) ps
    | Or ps ->
       List.fold_left
         (fun acc p ->
           match acc, check_prop_incomplete_state p state with
           | Some true, _ | _, Some true -> Some true
           | Some false, Some false -> Some false
           | _, _ -> None
         )
         (Some false) ps
    | Implies (p1, p2) ->
       check_prop_incomplete_state (Or [Not p1; p2]) state
  end
