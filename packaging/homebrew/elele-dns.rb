class EleleDns < Formula
  desc "Animated command-line control for the elele. DNS Docker dashboard"
  homepage "https://dns.elele.dev"
  url "https://github.com/Elele-Group/elele-dns-demo/archive/refs/heads/master.tar.gz"
  version "0.2.0"
  license "All rights reserved"

  depends_on "docker" => :recommended

  def install
    bin.install "bin/elele-dns"
    chmod 0755, bin/"elele-dns"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/elele-dns --version")
  end
end
