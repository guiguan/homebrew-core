class DockerMachineDriverXhyve < Formula
  desc "Docker Machine driver for xhyve"
  homepage "https://github.com/zchee/docker-machine-driver-xhyve"
  url "https://github.com/zchee/docker-machine-driver-xhyve.git",
    :tag => "v0.3.1",
    :revision => "ab0aebaeba32c3a3ca3c201c1e02dc35dd862c99"

  head "https://github.com/zchee/docker-machine-driver-xhyve.git"

  bottle do
    sha256 "b1d626f1d466e87f483cda698ccfa5e8d4e40bf25144e52d2387aaa0a1f1c1f7" => :sierra
    sha256 "af5f4d61072d524a27ecea05bac0e2ab75e8600d28c2ce442b993a84f20ffa1d" => :el_capitan
    sha256 "d90a5a24b067ef66ba5f81b6050e7111d8527ef189560a0cdc740acc8ba12e44" => :yosemite
  end

  option "without-qcow2", "Do not support qcow2 disk image format"

  depends_on :macos => :yosemite
  depends_on "go" => :build
  depends_on "docker-machine" => :recommended
  if build.with? "qcow2"
    depends_on "opam"
    depends_on "libev"
  end

  def install
    (buildpath/"gopath/src/github.com/zchee/docker-machine-driver-xhyve").install Dir["{*,.git,.gitignore,.gitmodules}"]

    ENV["GOPATH"] = "#{buildpath}/gopath"
    build_root = buildpath/"gopath/src/github.com/zchee/docker-machine-driver-xhyve"
    build_tags = "lib9p"

    cd build_root do
      git_hash = `git rev-parse --short HEAD --quiet`.chomp
      if build.head?
        git_hash = "HEAD-#{git_hash}"
      end

      if build.with? "qcow2"
        build_tags << " qcow2"
        system "opam", "init", "--no-setup"
        opam_dir = "#{buildpath}/.brew_home/.opam"
        ENV["CAML_LD_LIBRARY_PATH"] = "#{opam_dir}/system/lib/stublibs:/usr/local/lib/ocaml/stublibs"
        ENV["OPAMUTF8MSGS"] = "1"
        ENV["PERL5LIB"] = "#{opam_dir}/system/lib/perl5"
        ENV["OCAML_TOPLEVEL_PATH"] = "#{opam_dir}/system/lib/toplevel"
        ENV.prepend_path "PATH", "#{opam_dir}/system/bin"
        system "opam", "install", "-y", "uri", "qcow-format", "conf-libev"
      end

      go_ldflags = "-w -s -X 'github.com/zchee/docker-machine-driver-xhyve/xhyve.GitCommit=Homebrew#{git_hash}'"
      ENV["GO_LDFLAGS"] = go_ldflags
      ENV["GO_BUILD_TAGS"] = build_tags
      system "make", "lib9p"
      system "make", "build"
      bin.install "bin/docker-machine-driver-xhyve"
    end
  end

  def caveats; <<-EOS.undent
    This driver requires superuser privileges to access the hypervisor. To
    enable, execute
        sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
        sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
    EOS
  end

  test do
    assert_match "xhyve-memory-size",
    shell_output("#{Formula["docker-machine"].bin}/docker-machine create --driver xhyve -h")
  end
end
