%define ver 0.8.2
%define perllibdir %(eval "`perl -V:installvendorlib`"; echo $installvendorlib)

Name: onis
Summary: A logfile analyser and statistics generator for IRC-logfiles
Group: Applications/Internet
Version: %{ver}
Release: 1
Source0: http://verplant.org/onis/%{name}-%{ver}.tar.gz
URL: http://verplant.org/onis/
License: GPL
Requires: perl >= 5.6.0
AutoReqProv: no
BuildArch: noarch
Buildroot: %{_tmppath}/%{name}-root
Packager: Florian octo Forster <octo@verplant.org>

%description
Onis is a script that converts IRC logfiles into an HTML statistics page. It
provides information about daily channel usage, user activity, and channel
trivia. It provides a configurable customization and supports Dancer,
dircproxy, eggdrop, irssi, mIRC, and XChat logs. Persistent data (history
files) and automatic log purging make onis applicable for a large number of
logfiles. It also features a powerful translation infrastructure.

%prep
%setup
patch -p1 <contrib/systemwide-patch/systemwide-patch.diff

%build
pod2man -r "$(egrep '^\$VERSION' onis | cut -d \' -f 2)" onis >onis.1

%install
rm -fr $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT%_bindir \
         $RPM_BUILD_ROOT/etc/onis \
         $RPM_BUILD_ROOT%{perllibdir} \
         $RPM_BUILD_ROOT%{_datadir}/onis \
	 $RPM_BUILD_ROOT/var/lib/onis \
	 $RPM_BUILD_ROOT%{_mandir}/man1

cp onis $RPM_BUILD_ROOT%{_bindir}/
cp onis.conf users.conf $RPM_BUILD_ROOT/etc/onis/
cp -r lib/Onis $RPM_BUILD_ROOT%{perllibdir}/
cp -r themes lang $RPM_BUILD_ROOT%{_datadir}/onis/
cp -r reports/*-theme $RPM_BUILD_ROOT%{_datadir}/onis/themes/
cp onis.1 $RPM_BUILD_ROOT%{_mandir}/man1/

chmod 0755 $RPM_BUILD_ROOT%_bindir/onis
chmod -R 0644 $RPM_BUILD_ROOT/etc/onis/*
chmod -R a-w $RPM_BUILD_ROOT%{perllibdir}/Onis
chmod -R a-w $RPM_BUILD_ROOT%{_datadir}/onis
chmod -R a-w $RPM_BUILD_ROOT%{_mandir}/man1/onis.1

%clean
rm -fr $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc CHANGELOG THANKS README TODO FAQ COPYING
%config(noreplace) /etc/onis/*
%{_bindir}/onis
%{perllibdir}/Onis
%{_datadir}/onis
%{_mandir}/man1/*

%changelog
* Tue Jun 07 2005 Florian Forster <octo@verplant.org>
- New upstream version.

* Sat Apr 23 2005 Florian Forster <octo@verplant.org>
- Added generation of manpage.
- Rebuild for onis-0.8.1

* Mon Apr 18 2005 Florian Forster <octo@verplant.org>
- Initial build.
