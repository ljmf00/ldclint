project('ldclint', ['c','d'], version: '0.0.1')

fs = import('fs')

run_command('buildenv/fetch-ldc-source', check: true)

cc = meson.get_compiler('c')
dcompiler = meson.get_compiler('d')

ldclint_incdir = include_directories('source')

add_global_arguments('-J' + meson.current_build_dir() + '/ldc-src/dmd/res', language: 'd')
add_global_arguments('-I' + meson.current_build_dir() + '/ldc-src', language: 'd')
add_global_arguments('-I' + meson.current_build_dir() + '/ldc-src/runtime/druntime/src', language: 'd')
add_global_arguments('-I' + meson.current_build_dir() + '/ldc-src/runtime/phobos', language: 'd')

add_global_arguments('--conf=', language: 'd')
add_global_link_arguments('--conf=', language: 'd')

add_global_link_arguments('--defaultlib=', language: 'd')

# make visibility hidden by default, unless marked as `export`
add_global_arguments('--fvisibility=hidden', language: 'd')
add_global_link_arguments('--fvisibility=hidden', language: 'd')

dparse_incdir = include_directories('libdparse/src')

dparse_src = [
  'libdparse/src/dparse/formatter.d',
  'libdparse/src/dparse/stack_buffer.d',
  'libdparse/src/dparse/rollback_allocator.d',
  'libdparse/src/dparse/entities.d',
  'libdparse/src/dparse/parser.d',
  'libdparse/src/dparse/ast.d',
  'libdparse/src/dparse/astprinter.d',
  'libdparse/src/dparse/trivia.d',
  'libdparse/src/dparse/lexer.d',
  'libdparse/src/dparse/strings.d',
  'libdparse/src/std/experimental/lexer.d',
]

dparse_lib = static_library('dparse',
  dparse_src,
  include_directories: dparse_incdir,
  pic: true,
)

dparse_dep = declare_dependency(
  link_with: dparse_lib,
  include_directories: dparse_incdir,
)

ldclint_core_lib = static_library('ldclint-core',
  [
    'source/ldclint/dparseast.d',
    'source/ldclint/options.d',
    'source/ldclint/dmd/location.d',
    'source/ldclint/dmd/astutility.d',
    'source/ldclint/visitors.d',
    'source/ldclint/scopetracker.d',
    'source/ldclint/checks/unused.d',
    'source/ldclint/checks/structs_ctor_postblit.d',
    'source/ldclint/checks/atproperty.d',
    'source/ldclint/checks/redundant.d',
    'source/ldclint/checks/stack.d',
  ],
  dependencies: [ dparse_dep ],
  include_directories: ldclint_incdir,
  d_module_versions: [ 'IN_LLVM' ],
  pic: true,
)

ldclint_core_dep = declare_dependency(
  link_with: ldclint_core_lib,
  include_directories: ldclint_incdir,
  dependencies: [ dparse_dep ],
)

phobos2_ldc_dep = cc.find_library('phobos2-ldc', static: true)

ldclint_lib = shared_library('ldclint-' + dcompiler.version(),
  [
    'source/ldclint/plugin.d',
  ],
  dependencies: [ ldclint_core_dep, phobos2_ldc_dep ],
  include_directories: ldclint_incdir,
  d_module_versions: [ 'IN_LLVM' ],
  install: true,
  version: meson.project_version(),
)

ldclint_lib_name = fs.name(ldclint_lib.full_path())
if 'dll' in ldclint_lib_name
  ldclint_ext = 'dll'
elif 'dylib' in ldclint_lib_name
  ldclint_ext = 'dylib'
else
  ldclint_ext = 'so'
endif

install_symlink('libldclint.' + ldclint_ext,
  install_dir: get_option('libdir'),
  pointing_to: ldclint_lib_name
)
