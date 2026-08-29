// pybind11 module boundary. Placeholder: proves the build path (cmake ->
// shared object -> importable from the pipeline image) with no model in it.
//
// Add headers under engine/include, sources under engine/src, and list them in
// CMakeLists.txt. Return numpy arrays via py::array_t with a capsule owner so
// large results are not copied.

#include <pybind11/numpy.h>
#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

namespace py = pybind11;

PYBIND11_MODULE(engine, m) {
    m.doc() = "Computational engine (C++ hot path).";
    m.def("version", [] { return "0.1.0-placeholder"; });
}
