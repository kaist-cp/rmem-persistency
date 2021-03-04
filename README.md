# Model Checker for Persistency

This model checker is based on [rmem](https://github.com/rems-project/rmem), executable concurrency models for ARMv8, RISC-V, Power, and x86. In particular, this model checker basically uses the Promising model for ARMv8 and RISC-V by Pulte et al.

## Our extension

We extend the original checker to the PARMv8 model checker by supporting:

- ARMv8 instruction for persistency (i.e., DC CVAP)
- persistency views of PARMv8-view (i.e., VpReady, VpAsync, VpCommit)
- enumeration of states of when crash occurs at arbitrary point

## Build

```
sudo apt install -y findutils libgmp-dev m4 perl pkg-config zlib1g-dev z3
opam repository add rems https://github.com/rems-project/opam-repository.git#opam2
opam install --deps-only .
ulimit -s unlimited  #  Without this, a stack overflow may occur during build.
make MODE=opt ISA=AArch64
```

If it doesn't work, please read the `README.md` of [rmem](https://github.com/rems-project/rmem) for more details.

## Run an example

We use our model checker to verify several representative persistent synchronization examples, including *all* examples presented in the paper (modulo architectural differences) and the "Atomic Persists" example in [Raad et al. (Example 3)](http://plv.mpi-sws.org/pog/paper.pdf) for modeling persistent transaction. All of these examples are in [parmv8-view-examples](parmv8-view-examples).

To run one of examples:

```
./run.p [litmus file]
```

A Litmus file and the corresponding `shared_memory.txt` must be in the same directory.

For example, the following command is to enumerate every states that the **(COMMIT WEAK)** example can be reachable in case of either normal termination or an unexpected crash:

```
./run.p parmv8-view-examples/commit_weak/commit_weak.litmus
```

Then the output is printed out like below:

```
Test commit_weak Allowed
Shared-memory=0x0000000000001000 (data)/8; 0x0000000000001100 (commit)/8;
Memory-writes=
States 3
1     *>data=0x0; commit=0x0;  via "0"
1     :>data=0x2a; commit=0x0;  via "1;0"
2     :>data=0x2a; commit=0x1;  via "1;1;0"
NVM States 4
4     :>data=0x0; commit=0x0;
2     :>data=0x0; commit=0x1;
3     :>data=0x2a; commit=0x0;
2     :>data=0x2a; commit=0x1;
Deadlock states 1  via "2;0"
Unhandled exceptions 0
Ok
Condition exists (data=0x0 /\ commit=0x0)
Hash=98aca2103a7db7335c83aa17e3f47b8c
Observation commit_weak Sometimes 1 2 with deadlocks
Runtime: 0.034074 sec
```

`NVM States` in the middle is a list of all the reachable states of NVM when a program crashes while running or when the program ends. In this case, we can conclude that the desired invariant *"commit=1 ⇒ data=42"* doesn't hold because the state `data=0x0; commit=0x1;` denoting *"data=0 ∧ commit=1"* is on the list.

On the other hand, the output from the command `./run.p parmv8-view-examples/commit1/commit1.litmus` to check the **(COMMIT1)** example is like below:

```
Test commit1 Allowed
Shared-memory=0x0000000000001000 (data)/8; 0x0000000000001100 (commit)/8;
Memory-writes=
States 3
1     *>data=0x0; commit=0x0;  via "0"
1     :>data=0x2a; commit=0x0;  via "1;0"
1     :>data=0x2a; commit=0x1;  via "1;1;0;0"
NVM States 3
2     :>data=0x0; commit=0x0;
2     :>data=0x2a; commit=0x0;
1     :>data=0x2a; commit=0x1;
Unhandled exceptions 0
Ok
Condition exists (data=0x0 /\ commit=0x0)
Hash=d126aef71c01c0b3308c22bd06292d09
Observation commit1 Sometimes 1 2
Runtime: 0.033494 sec
```

We can conclude the invariant *"commit=1 ⇒ data=42"* holds in this case because there is no NVM state other than *data=42(0x2a)* when *commit=1*.

## Run all examples

You can run all PARMv8-view examples in [parmv8-view-examples](parmv8-view-examples) by executing this script:

```
./run_parmv8_all.p
```
