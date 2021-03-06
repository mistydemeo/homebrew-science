class Mumps < Formula
  homepage "http://mumps.enseeiht.fr"
  url "http://mumps.enseeiht.fr/MUMPS_4.10.0.tar.gz"
  mirror "http://graal.ens-lyon.fr/MUMPS/MUMPS_4.10.0.tar.gz"
  sha1 "904b1d816272d99f1f53913cbd4789a5be1838f7"
  revision 2

  bottle do
    root_url "https://downloads.sf.net/project/machomebrew/Bottles/science"
    revision 3
    sha1 "69b956e23f2b387c459057800c56b6165faebeff" => :yosemite
    sha1 "d3b4d49cff5b39b43df1d5fb23be754e2e52f327" => :mavericks
    sha1 "88ee0320fc58d658afef2fd409a62d4d16758057" => :mountain_lion
  end

  depends_on "scotch5" => :optional     # Scotch 6 support currently broken.
  depends_on "openblas" => :optional

  depends_on :mpi => [:cc, :cxx, :f90, :recommended]
  if build.with? :mpi
    depends_on "scalapack" => (build.with? "openblas") ? ["with-openblas"] : :build
  end
  depends_on "metis4" => :optional if build.without? :mpi

  depends_on :fortran

  def install
    make_args = ["LIBEXT=.dylib",
                 "AR=$(FL) -shared -Wl,-install_name -Wl,#{lib}/$(notdir $@) -undefined dynamic_lookup -o ",
                 "RANLIB=echo"]
    orderingsf = "-Dpord"

    makefile = (build.with? :mpi) ? "Makefile.gfortran.PAR" : "Makefile.gfortran.SEQ"
    cp "Make.inc/" + makefile, "Makefile.inc"

    if build.with? "scotch5"
      make_args += ["SCOTCHDIR=#{Formula['scotch5'].opt_prefix}",
                    "ISCOTCH=-I#{Formula['scotch5'].opt_include}"]

      if build.with? :mpi
        make_args << "LSCOTCH=-L$(SCOTCHDIR)/lib -lptesmumps -lptscotch -lptscotcherr"
        orderingsf << " -Dptscotch"
      else
        make_args << "LSCOTCH=-L$(SCOTCHDIR) -lesmumps -lscotch -lscotcherr"
        orderingsf << " -Dscotch"
      end
    end

    if build.with? "metis4"
      make_args += ["LMETISDIR=#{Formula['metis4'].opt_lib}",
                    "IMETIS=#{Formula['metis4'].opt_include}",
                    "LMETIS=-L#{Formula['metis4'].opt_lib} -lmetis"]
      orderingsf << " -Dmetis"
    end

    make_args << "ORDERINGSF=#{orderingsf}"

    if build.with? :mpi
      make_args += ["CC=#{ENV['MPICC']} -fPIC",
                    "FC=#{ENV['MPIFC']} -fPIC",
                    "FL=#{ENV['FC']} -fPIC",
                    "SCALAP=-L#{Formula['scalapack'].opt_lib} -lscalapack",
                    "INCPAR=-I#{Formula['open-mpi'].opt_include}",
                    "LIBPAR=$(SCALAP) -L#{Formula['open-mpi'].opt_lib} -lmpi -lmpi_mpifh"]
    else
      make_args += ["CC=#{ENV['CC']} -fPIC",
                    "FC=#{ENV['FC']} -fPIC",
                    "FL=#{ENV['FC']} -fPIC"]
    end

    if build.with? "openblas"
      make_args << "LIBBLAS=-L#{Formula['openblas'].opt_lib} -lopenblas"
    else
      make_args << "LIBBLAS=-lblas -llapack"
    end

    ENV.deparallelize  # Build fails in parallel on Mavericks.
    system "make", "all", *make_args

    lib.install Dir["lib/*"]

    if build.with? :mpi
      include.install Dir["include/*"]
    else
      lib.install "libseq/libmpiseq.dylib"
      libexec.install "include"
      include.install_symlink Dir[libexec / "include/*"]
      # The following .h files may conflict with others related to MPI
      # in /usr/local/include. Do not symlink them.
      (libexec / "include").install Dir["libseq/*.h"]
    end

    doc.install Dir["doc/*.pdf"]
    (share + "mumps/examples").install Dir["examples/*[^.o]"]

    prefix.install "Makefile.inc"  # For the record.
    File.open(prefix / "make_args.txt", "w") do |f|
      f.puts(make_args.join(" "))  # Record options passed to make.
    end
  end

  def caveats
    s = ""
    if build.without? :mpi
      s += <<-EOS.undent
      You built a sequential MUMPS library.
      Please add #{libexec}/include to the include path
      when building software that depends on MUMPS.
      EOS
    end
    s
  end

  test do
    cmd = build.without?(:mpi) ? "" : "mpirun -np 2"
    system "#{cmd} #{share}/mumps/examples/ssimpletest < #{share}/mumps/examples/input_simpletest_real"
    system "#{cmd} #{share}/mumps/examples/dsimpletest < #{share}/mumps/examples/input_simpletest_real"
    system "#{cmd} #{share}/mumps/examples/csimpletest < #{share}/mumps/examples/input_simpletest_cmplx"
    system "#{cmd} #{share}/mumps/examples/zsimpletest < #{share}/mumps/examples/input_simpletest_cmplx"
    system "#{cmd} #{share}/mumps/examples/c_example"
    ohai "Test results are in ~/Library/Logs/Homebrew/mumps"
  end
end
