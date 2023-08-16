project('ldclint', 'd')

ldclint_incdir = include_directories('source')

add_global_arguments('-J' + meson.current_source_dir() + '/ldc/dmd/res', language: 'd')
add_global_arguments('-I' + meson.current_source_dir() + '/ldc', language: 'd')
add_global_arguments('-I' + meson.current_source_dir() + '/ldc/runtime/druntime', language: 'd')
add_global_arguments('-I' + meson.current_source_dir() + '/ldc/runtime/phobos', language: 'd')

add_global_arguments('--defaultlib=', language: 'd')
add_global_link_arguments('--defaultlib=', language: 'd')

# make visibility hidden by default, unless marked as `export`
add_global_arguments('--fvisibility=hidden', language: 'd')
add_global_link_arguments('--fvisibility=hidden', language: 'd')

shared_library('ldclint',
  [
    'source/ldclint/plugin.d',
    'source/ldclint/dmd/location.d',
    'source/ldclint/visitors.d',
    'source/ldclint/checks/unused.d',
    'source/ldclint/checks/structs_ctor_postblit.d',
  ],
  include_directories: ldclint_incdir,
  d_module_versions: [ 'IN_LLVM' ],
)
