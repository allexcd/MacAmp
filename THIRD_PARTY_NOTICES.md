# Third-party software

Mac-Amp's own code is MIT-licensed (see LICENSE). It uses SFBAudioEngine 0.14.0 (MIT), by Stephen F. Booth, and the transitive dependencies pinned in Package.resolved. Full upstream license notices collected from the resolved packages are in Licenses/ and must accompany builds.

The engine's default package includes LGPL components: LAME, mpg123, libsndfile, Musepack, and TTA. TagLib is dual LGPL/MPL; Monkey's Audio has its own license. The included package-wrapper notices do not necessarily contain every codec's upstream notice. This prototype is not cleared for App Store distribution: before distributing, audit every embedded binary and upstream license, collect all required notices and corresponding source/relinking materials, and either satisfy applicable terms or build a reduced engine excluding incompatible/unneeded components. Merely including this notice does not establish compliance.

Xiph codecs (Ogg, Opus, Vorbis, FLAC) and several engine utilities use permissive licenses; see the individual notices. The player uses no Winamp artwork, logos, skin files, or source code.
