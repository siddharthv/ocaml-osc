# OPAM packages needed to build tests.
OPAM_PACKAGES="ocplib-endian ounit"


case "$OCAML_VERSION,$OPAM_VERSION" in
3.12.1,1.0.0) ppa=avsm/ocaml312+opam10 ;;
3.12.1,1.1.0) ppa=avsm/ocaml312+opam11 ;;
4.00.1,1.0.0) ppa=avsm/ocaml40+opam10 ;;
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.01.0,1.0.0) ppa=avsm/ocaml41+opam10 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac

echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
export OPAMYES=1
export OPAMVERBOSE=1
echo OCaml version
ocaml -version
echo OPAM versions
opam --version
opam --git-version

opam init 
opam install ${OPAM_PACKAGES}
if [ $INSTALL_LWT -eq 1 ]
then
    opam install lwt
fi

eval `opam config -env`

#install patched bisect library since it is not updated on opam yet$
echo '** INSTALLING PATCHED BISECT LIBRARY'
curl -L http://bisect.sagotch.fr | tar -xzf -
cd Bisect
chmod +x configure
./configure
cat Makefile.config
make all
sudo make install # ./configure set PATH_OCAML_PREFIX=/usr instead of$
                  # using .opam directory, so we need sudo$
cd ..
make
echo '** TEST CODE COVERAGE'$
make test
make doc
make coverage
