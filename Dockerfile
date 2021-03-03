From ocaml/opam:ubuntu-20.04-ocaml-4.10

COPY --chown=opam:opam . rmem-persistency
WORKDIR rmem-persistency

RUN sudo apt-get install -y findutils libgmp-dev m4 perl pkg-config zlib1g-dev z3 \
    && sudo rm -rf /var/lib/apt/lists/* \
    && opam repository add rems https://github.com/rems-project/opam-repository.git#opam2 \
    && opam install --deps-only .

RUN eval $(opam env) \
    && ulimit -s unlimited \
    && make MODE=opt ISA=AArch64
