# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

# Versioning policy for this artifact:
# We pin to specific upstream release tags (bXXXX) using a Portage-compliant
# version string of the form "0_pXXXX" (because Gentoo versions must start with a digit).
# This gives much better binpkg behavior and reproducibility than a 9999 live ebuild.
#
# Upgrade procedure when you want to follow a new upstream release:
#   1. Rename this file:  llama-cpp-0_p9354.ebuild  →  llama-cpp-0_p9500.ebuild (example)
#   2. (Rarely) adjust any patches or flags in the new ebuild
#   3. Regenerate Manifest:  ebuild ... manifest
#   4. Rebuild Lower layer (genpack lower) — the new version will be built/cached
#
# This is cleaner than a 9999 live ebuild for a genpack artifact.

# Upstream uses tags like "b9354". We use "0_p9354" only as the Portage version
# (in the ebuild filename) to satisfy Gentoo's rule that versions must start with a digit.
UPSTREAM_TAG="b9354"

MY_P="llama.cpp-${UPSTREAM_TAG}"

DESCRIPTION="Port of Facebook's LLaMA model in C/C++ (Vulkan backend optimized for genpack)"
HOMEPAGE="https://github.com/ggml-org/llama.cpp"
SRC_URI="
    https://github.com/ggml-org/llama.cpp/archive/refs/tags/${UPSTREAM_TAG}.tar.gz -> ${MY_P}.tar.gz
    https://github.com/ggml-org/llama.cpp/releases/download/${UPSTREAM_TAG}/llama-${UPSTREAM_TAG}-ui.tar.gz
"

S="${WORKDIR}/${MY_P}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64"

# vulkan is enabled by default: Vulkan-capable hardware is extremely widespread
# (Intel/AMD via mesa, NVIDIA via nvidia-drivers), and with GGML_BACKEND_DL=ON a
# system lacking a Vulkan ICD simply doesn't load libggml-vulkan.so and falls back
# to the CPU backend — so defaulting it ON has essentially no downside.
IUSE="+vulkan"

# Dependency split (EAPI 8): keep build-only tooling out of the runtime image.
#   - dev-build/cmake is NOT listed: cmake.eclass already adds it to BDEPEND.
#   - BDEPEND: the Vulkan shader toolchain runs on the build host to compile the
#     GLSL compute shaders to SPIR-V at build time; none of it is needed at runtime.
#   - DEPEND: headers compiled against, plus vulkan-loader linked against.
#   - RDEPEND: only the Vulkan loader — libggml-vulkan.so dlopen-loads it via
#     libvulkan.so.1 at runtime (confirmed via the built binpkg's NEEDED/REQUIRES).
# No nodejs BDEPEND needed: we consume the pre-built UI tarball attached to the GitHub
# release (avoids npm entirely during the Portage build, blocked by network-sandbox).
BDEPEND="
	vulkan? (
		media-libs/shaderc
		dev-util/glslang
		dev-util/spirv-tools
		dev-util/spirv-headers
	)
"
DEPEND="
	vulkan? (
		dev-util/vulkan-headers
		media-libs/vulkan-loader
	)
"
RDEPEND="
	vulkan? (
		media-libs/vulkan-loader
	)
"

src_prepare() {
    cmake_src_prepare

    # Populate tools/ui/dist/ from the GitHub release-attached UI tarball.
    # This hits Priority 1 in ui-assets.cmake → no npm, no HF download at build time.
    # The UI tarball is named llama-${tag}-ui.tar.gz and extracts to a directory
    # containing exactly the 4 needed files (different dir name from the main source).
    mkdir -p "${S}/tools/ui/dist" || die
    cp "${WORKDIR}/llama-${UPSTREAM_TAG}"/{bundle.css,bundle.js,index.html,loading.html} \
        "${S}/tools/ui/dist/" || die
}

src_configure() {
	local mycmakeargs=(
		-DGGML_VULKAN=$(usex vulkan ON OFF)
		-DGGML_NATIVE=OFF
		-DGGML_BACKEND_DL=ON
		-DGGML_CPU_ALL_VARIANTS=ON
		-DCMAKE_BUILD_TYPE=Release
		-DLLAMA_BUILD_TESTS=OFF
		# Good defaults for a portable system image
		-DLLAMA_BUILD_EXAMPLES=ON
		-DLLAMA_BUILD_SERVER=ON
		# Enable the new UI embedding system (tools/ui + host compiler embed)
		# and disable HF prebuilt fallback so we get embedded WebUI
		# purely from local npm build (no network download of assets).
		-DLLAMA_BUILD_UI=ON
		-DLLAMA_USE_PREBUILT_UI=OFF
		# Prevent the vendored ggml from installing its headers and cmake config.
		# llama.cpp vendors a specific ggml snapshot; we don't want it to collide
		# with any future system ggml or other packages that might install ggml.
		-DGGML_INSTALL=OFF
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Belt-and-suspenders: the vendored ggml inside llama.cpp can still leak
	# some headers/cmake files even with GGML_INSTALL=OFF in some snapshots.
	# We explicitly remove the public ggml/gguf headers and cmake config
	# so they never collide with anything else in the image.
	# (llama itself only needs its own llama.h + the built libraries.)
	rm -rf "${D}/usr/include/ggml"* \
	       "${D}/usr/include/gguf.h" \
	       "${D}/usr/lib64/cmake/ggml" || die
}

pkg_postinst() {
	elog "llama.cpp (Vulkan) has been installed."
	elog "Test with: ZES_ENABLE_SYSMAN=1 llama-cli -m /path/to/model.gguf -ngl 99"
	elog ""
	elog "llama-server is also available (WebUI included)."
	elog "Example with WebUI:"
	elog "  llama-server -m /path/to/model.gguf --public-path /usr/share/llama.cpp/server"
	elog ""
	elog "This ebuild is pinned to upstream release tag ${UPSTREAM_TAG}."
	elog "To upgrade to a newer release, rename the ebuild file and"
	elog "regenerate the Manifest (see top of this ebuild for the exact procedure)."
}
