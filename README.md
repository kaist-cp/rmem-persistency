# Model Checker for Persistency


This model checker is a fork of [rmem](https://github.com/rems-project/rmem), executable concurrency models for ARMv8, RISC-V, Power, and x86.  This model checker reuses the Promising model for ARMv8 and RISC-V by Pulte et al.


Related publications:

- Christopher Pulte, Jean Pichon-Pharabod, Jeehoon Kang, Sung-Hwan Lee, Chung-Kil Hur.  Promising-ARM/RISC-V: a simpler and faster operational concurrency model.  PLDI 2019.

- Kyeongmin Cho, Sung-Hwan Lee, Azalea Raad, and Jeehoon Kang.  Revamping Hardware Persistency Models: View-based and Axiomatic Persistency Models for Intel-x86 and ARMv8.  PLDI 2021 (conditionally accepted).


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

We use our model checker to verify several representative persistent synchronization examples, including the "Atomic Persists" example in [Raad et al. (Example 3)](http://plv.mpi-sws.org/pog/paper.pdf) for modeling persistent transaction. All of these examples are in [parmv8-view-examples](parmv8-view-examples).

### How to run and verify an example

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

We can conclude the invariant *"commit=1 ⇒ data=42"* holds in this case because there is no other NVM state than *data=42*(`0x2a`) when *commit=1*.

### Expected output and verification of all examples

#### "atomic_persists"

- **Output**:
    ```
    Test atomic_persists Allowed
    Shared-memory=0x0000000000001000 (lock)/8; 0x0000000000001100 (Z)/8; 0x0000000000001200 (Y)/8; 0x0000000000001300 (X)/8;
    Memory-writes=
    States 7
    2     *>0:X30=0x0; 1:X30=0x0; lock=0x0; Z=0x0; Y=0x0; X=0x0;  via "0"
    12    :>0:X30=0x0; 1:X30=0x0; lock=0x0; Z=0x0; Y=0x1; X=0x1;  via "1;1;1;1;0;0"
    12    :>0:X30=0x0; 1:X30=0x0; lock=0x0; Z=0x1; Y=0x1; X=0x1;  via "1;1;1;1;1;1;1;0;0"
    3     :>0:X30=0x0; 1:X30=0x0; lock=0x1; Z=0x0; Y=0x0; X=0x0;  via "1;0;0"
    4     :>0:X30=0x0; 1:X30=0x0; lock=0x1; Z=0x0; Y=0x0; X=0x1;  via "1;2;0;0"
    18    :>0:X30=0x0; 1:X30=0x0; lock=0x1; Z=0x0; Y=0x1; X=0x1;  via "1;1;1;0;0"
    12    :>0:X30=0x0; 1:X30=0x0; lock=0x1; Z=0x1; Y=0x1; X=0x1;  via "1;1;1;1;1;1;0;0"
    NVM States 10
    21    :>lock=0x0; Z=0x0; Y=0x0; X=0x0;
    16    :>lock=0x0; Z=0x0; Y=0x0; X=0x1;
    12    :>lock=0x0; Z=0x0; Y=0x1; X=0x0;
    42    :>lock=0x0; Z=0x0; Y=0x1; X=0x1;
    24    :>lock=0x0; Z=0x1; Y=0x1; X=0x1;
    20    :>lock=0x1; Z=0x0; Y=0x0; X=0x0;
    16    :>lock=0x1; Z=0x0; Y=0x0; X=0x1;
    12    :>lock=0x1; Z=0x0; Y=0x1; X=0x0;
    42    :>lock=0x1; Z=0x0; Y=0x1; X=0x1;
    24    :>lock=0x1; Z=0x1; Y=0x1; X=0x1;
    Deadlock states 53  via "2;0"
    Unhandled exceptions 0
    Ok
    Condition exists (0:X30=0x0 /\ 1:X30=0x0 /\ lock=0x0 /\ X=0x0 /\ Y=0x0 /\ Z=0x0)
    Hash=c609d41936e8c98862016f7a1741531b
    Observation atomic_persists Sometimes 1 6 with deadlocks
    Runtime: 0.276038 sec
    ```
- **Target invariant**: "z=1 ⇒ x=1 ∧ y=1"
- **Verification**: The invariant *holds* since there is no other NVM state than {x=1, y=1} when z=1.

#### "commit1"

- **Output**:
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
    Runtime: 0.037037 sec
    ```
- **Target invariant**: "commit=1 ⇒ data=42"
- **Verification**: The invariant *holds* since there is no other NVM state than data=42 when commit=1.

#### "commit2"

- **Output**:
    ```
    Test commit2 Allowed
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
    Hash=09202897b38b9b5a734ce3e8ae76b2b6
    Observation commit2 Sometimes 1 2
    Runtime: 0.039360 sec
    ```
- **Target invariant**: "commit=1 ⇒ data=42"
- **Verification**: The invariant *holds* since there is no other NVM state than data=42 when commit=1.

#### "commit2_opt"

- **Output**:
    ```
    Test commit2_opt Allowed
    Shared-memory=0x0000000000001000 (data)/8; 0x0000000000001100 (commit)/8;
    Memory-writes=
    States 3
    1     *>data=0x0; commit=0x0;  via "0"
    1     :>data=0x2a; commit=0x0;  via "1;0"
    1     :>data=0x2a; commit=0x1;  via "1;1;0;0"
    NVM States 4
    3     :>data=0x0; commit=0x0;
    1     :>data=0x0; commit=0x1;
    2     :>data=0x2a; commit=0x0;
    1     :>data=0x2a; commit=0x1;
    Unhandled exceptions 0
    Ok
    Condition exists (data=0x0 /\ commit=0x0)
    Hash=f2c3d2528818e2a2cd912e89a96fbaa1
    Observation commit2_opt Sometimes 1 2
    Runtime: 0.040088 sec
    ```
- **Target invariant**: "(data=0 ∨ data=42) ∧ (commit=0 ∨ commit=1)"
- **Verification**: The invariant *holds* since all states in the NVM States contain only data = 0 or 42, commit = 0 or 1.

#### "commit_opt"

- **Output**:
    ```
    Test commit_opt Allowed
    Shared-memory=0x0000000000001000 (data2)/8; 0x0000000000001100 (data1)/8; 0x0000000000001200 (commit)/8;
    Memory-writes=
    States 4
    1     *>data2=0x0; data1=0x0; commit=0x0;  via "0"
    1     :>data2=0x0; data1=0x2a; commit=0x0;  via "1;0"
    1     :>data2=0x7; data1=0x2a; commit=0x0;  via "1;1;0;0"
    1     :>data2=0x7; data1=0x2a; commit=0x1;  via "1;1;1;0;0"
    NVM States 5
    3     :>data2=0x0; data1=0x0; commit=0x0;
    2     :>data2=0x0; data1=0x2a; commit=0x0;
    1     :>data2=0x7; data1=0x0; commit=0x0;
    2     :>data2=0x7; data1=0x2a; commit=0x0;
    1     :>data2=0x7; data1=0x2a; commit=0x1;
    Unhandled exceptions 0
    Ok
    Condition exists (data1=0x0 /\ data2=0x0 /\ commit=0x0)
    Hash=b872b6f6254f4ee00d5db94bc872db96
    Observation commit_opt Sometimes 1 3
    Runtime: 0.041574 sec
    ```
- **Target invariant**: "commit=1 ⇒ data1=42 ∧ data2=7"
- **Verification**: The invariant *holds* since there is no other NVM state than {data1=42, data2=7} when commit=1.

#### "commit_weak"

- Output:
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
    Runtime: 0.038537 sec
    ```
- **Target invariant**: "commit=1 ⇒ data=42"
- **Verification**: The invariant *does not hold* since there is a state data=0 when commit=1.

#### "commit_weak_opt"

- **Output**:
    ```
    Test commit_weak_opt Allowed
    Shared-memory=0x0000000000001000 (data)/8; 0x0000000000001100 (commit)/8;
    Memory-writes=
    States 3
    1     *>data=0x0; commit=0x0;  via "0"
    1     :>data=0x2a; commit=0x0;  via "1;0"
    2     :>data=0x2a; commit=0x1;  via "1;1;0;0"
    NVM States 4
    4     :>data=0x0; commit=0x0;
    2     :>data=0x0; commit=0x1;
    3     :>data=0x2a; commit=0x0;
    2     :>data=0x2a; commit=0x1;
    Deadlock states 1  via "2;0"
    Unhandled exceptions 0
    Ok
    Condition exists (data=0x0 /\ commit=0x0)
    Hash=dbdc76b8b93b68d6de11c09848b0f83a
    Observation commit_weak_opt Sometimes 1 2 with deadlocks
    Runtime: 0.038746 sec
    ```
- **Target invariant**: "(data=0 ∨ data=42) ∧ (commit=0 ∨ commit=1)"
- **Verification**: The invariant *holds* since all states in the NVM States contain only data = 0 or 42, commit = 0 or 1.

#### "flush_mca"

- **Output**:
    ```
    Test flush_mca Allowed
    Shared-memory=0x0000000000001000 (Z)/8; 0x0000000000001100 (Y)/8; 0x0000000000001200 (X)/8; 0x0000000000001300 (W)/8;
    Memory-writes=
    States 9
    1     *>Z=0x0; Y=0x0; X=0x0; W=0x0;  via "0"
    1     :>Z=0x0; Y=0x0; X=0x1; W=0x0;  via "1;0"
    1     :>Z=0x0; Y=0x1; X=0x0; W=0x0;  via "2;0"
    1     :>Z=0x0; Y=0x1; X=0x0; W=0x1;  via "2;2;0;0"
    2     :>Z=0x0; Y=0x1; X=0x1; W=0x0;  via "1;2;0"
    3     :>Z=0x0; Y=0x1; X=0x1; W=0x1;  via "1;2;2;0;0"
    1     :>Z=0x1; Y=0x0; X=0x1; W=0x0;  via "1;1;0;0"
    3     :>Z=0x1; Y=0x1; X=0x1; W=0x0;  via "1;1;1;0;0"
    6     :>Z=0x1; Y=0x1; X=0x1; W=0x1;  via "1;1;1;1;0;0"
    NVM States 15
    11    :>Z=0x0; Y=0x0; X=0x0; W=0x0;
    3     :>Z=0x0; Y=0x0; X=0x0; W=0x1;
    12    :>Z=0x0; Y=0x0; X=0x1; W=0x0;
    6     :>Z=0x0; Y=0x0; X=0x1; W=0x1;
    12    :>Z=0x0; Y=0x1; X=0x0; W=0x0;
    6     :>Z=0x0; Y=0x1; X=0x0; W=0x1;
    14    :>Z=0x0; Y=0x1; X=0x1; W=0x0;
    9     :>Z=0x0; Y=0x1; X=0x1; W=0x1;
    3     :>Z=0x1; Y=0x0; X=0x0; W=0x0;
    6     :>Z=0x1; Y=0x0; X=0x1; W=0x0;
    3     :>Z=0x1; Y=0x0; X=0x1; W=0x1;
    6     :>Z=0x1; Y=0x1; X=0x0; W=0x0;
    3     :>Z=0x1; Y=0x1; X=0x0; W=0x1;
    9     :>Z=0x1; Y=0x1; X=0x1; W=0x0;
    6     :>Z=0x1; Y=0x1; X=0x1; W=0x1;
    Unhandled exceptions 0
    Ok
    Condition exists (X=0x0 /\ Y=0x0 /\ Z=0x0 /\ W=0x0)
    Hash=fa1fb39e4e97bf23fcfd743bde0a2f3f
    Observation flush_mca Sometimes 1 8
    Runtime: 0.072553 sec
    ```
- **Target invariant**: "z=w=1 ⇒ (x=1 ∨ y=1)"
- **Verification**: The invariant *holds* since all states in the NVM States, when z=w=1, contain only x=1 or y=1.

#### "fob"

- **Output**:
    ```
    Test fob Allowed
    Shared-memory=0x0000000000001000 (Z)/8; 0x0000000000001100 (Y)/8; 0x0000000000001200 (X)/8;
    Memory-writes=
    States 4
    2     *>Z=0x0; Y=0x0; X=0x0;  via "0"
    3     :>Z=0x0; Y=0x0; X=0x1;  via "1;0"
    4     :>Z=0x0; Y=0x1; X=0x1;  via "1;1;0;0"
    1     :>Z=0x1; Y=0x1; X=0x1;  via "1;1;2;0;0"
    NVM States 6
    9     :>Z=0x0; Y=0x0; X=0x0;
    8     :>Z=0x0; Y=0x0; X=0x1;
    4     :>Z=0x0; Y=0x1; X=0x0;
    5     :>Z=0x0; Y=0x1; X=0x1;
    1     :>Z=0x1; Y=0x0; X=0x1;
    1     :>Z=0x1; Y=0x1; X=0x1;
    Unhandled exceptions 0
    Ok
    Condition exists (X=0x0 /\ Y=0x0 /\ Z=0x0)
    Hash=301aa80501fde3394118d23d590d71cd
    Observation fob Sometimes 1 3
    Runtime: 0.053252 sec
    ```
- **Target invariant**: "z=1 ⇒ x=1"
- **Verification**: The invariant *holds* since there is no other NVM state than x=1 when z=1.

## Run all examples

You can run all PARMv8-view examples in [parmv8-view-examples](parmv8-view-examples) by executing this script:

```
./run_parmv8_all.p
```
