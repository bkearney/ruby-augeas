# -*- ruby -*-
# Rakefile: build ruby auges bindings
#
# Copyright (C) 2008 Red Hat, Inc.
#
# Distributed under the GNU Lesser General Public License v2.1 or later.
# See COPYING for details
#
# Bryan Kearney <bkearney@redhat.com>

require 'rubygems'
require 'rake/clean'
require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/gempackagetask'

PKG_NAME='ruby-augeas'
GEM_NAME=PKG_NAME # we'd like 'augeas' but that makes RPM fail
PKG_VERSION='0.4.0'
SPEC_FILE="ruby-augeas.spec"

#
# Building the actual bits
#
CLEAN.include [ "**/*~", "build"]

CLOBBER.include [ "config.save"]

#
# Testing
#
Rake::TestTask.new(:test) do |t|
    t.test_files = FileList['tests/tc_*.rb']
    t.ruby_opts = ["-rubygems"]
    t.libs = [ 'lib' ]
end


#
# Generate the documentation
#
Rake::RDocTask.new do |rd|
    rd.main = "README.rdoc"
    rd.rdoc_dir = "doc/site/api"
    rd.rdoc_files.include("README.rdoc","lib/**/*.rb")
end

#
# Packaging
#
PKG_FILES = FileList[
  "Rakefile", "COPYING","README.rdoc", "NEWS",
  "lib/**/*.rb", "tests/**/*",
  "spec/**/*"
]

DIST_FILES = FileList[
  "pkg/*.tgz", "pkg/*.gem"
]

SPEC = Gem::Specification.new do |s|
    s.name = GEM_NAME
    s.version = PKG_VERSION
    s.email = "augeas-devel@redhat.com"
    s.homepage = "http://augeas.net/"
    s.summary = "Ruby bindings for augeas"
    s.files = PKG_FILES
    s.autorequire = "augeas"
    s.requirements = 'ffi>3.0.5'
    s.required_ruby_version = '>= 1.8.1'
    s.description = "Provides bindings for augeas."
end

Rake::GemPackageTask.new(SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
end

desc "Build (S)RPM for #{PKG_NAME}"
task :rpm => [ :package ] do |t|
    system("sed -e 's/@VERSION@/#{PKG_VERSION}/' #{SPEC_FILE} > pkg/#{SPEC_FILE}")
    Dir::chdir("pkg") do |dir|
        dir = File::expand_path(".")
        system("rpmbuild --define '_topdir #{dir}' --define '_sourcedir #{dir}' --define '_srcrpmdir #{dir}' --define '_rpmdir #{dir}' --define '_builddir #{dir}' -ba #{SPEC_FILE} > rpmbuild.log 2>&1")
        if $? != 0
            raise "rpmbuild failed"
        end
    end
end

desc "Release a version to the site"
task :dist => [ :rpm ] do |t|
    puts "Copying files"
    unless sh "scp -p #{DIST_FILES.to_s} et:/var/www/sites/augeas.et.redhat.com/download/ruby"
        $stderr.puts "Copy to et failed"
        break
    end
    puts "Commit and tag #{PKG_VERSION}"
    system "hg commit -m 'Released version #{PKG_VERSION}'"
    system "hg tag -m 'Tag release #{PKG_VERSION}' release-#{PKG_VERSION}"
end

task :sync do |t|
    system "rsync -rav doc/site/ et:/var/www/sites/augeas.et.redhat.com/docs/ruby/"
end
