// ----------------------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------------------

/**
 * @file
 * utils.cuh
 *
 * @brief General graph-building utility routines
 */

#pragma once

// #define USE_STD_RANDOM          // undefine to use {s,d}rand48_r
#ifdef __APPLE__
#ifdef __clang__
#define USE_STD_RANDOM  // OS X/clang has no {s,d}rand48_r
#endif
#endif
#ifdef USE_STD_RANDOM
#include <random>
// this struct is a bit of a hack, but allows us to change as little
// code as possible in keeping {s,d}rand48_r capability as well as to
// use <random>
struct drand48_data {
  std::mt19937_64 engine;
  std::uniform_real_distribution<double> dist;
};
#endif

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <algorithm>
#include <omp.h>

#include <gunrock/util/error_utils.cuh>
#include <gunrock/util/random_bits.h>

//#include <gunrock/coo.cuh>
//#include <gunrock/csr.cuh>

namespace gunrock {
namespace graphio {

/**
 * @brief Generates a random node-ID in the range of [0, num_nodes)
 *
 * @param[in] num_nodes Number of nodes in Graph
 *
 * \return random node-ID
 */
template <typename SizeT>
SizeT RandomNode(SizeT num_nodes) {
  SizeT node_id;
  util::RandomBits(node_id);
  if (node_id < 0) node_id *= -1;
  return node_id % num_nodes;
}

template <typename GraphT>
cudaError_t MakeUndirected(GraphT &directed_graph, GraphT &undirected_graph,
                           bool remove_duplicate_edges = false) {
  typedef typename GraphT::VertexT VertexT;
  typedef typename GraphT::SizeT SizeT;
  typedef typename GraphT::ValueT ValueT;
  const graph::GraphFlag FLAG = GraphT::FLAG;
  typedef graph::Coo<VertexT, SizeT, ValueT,
                     (FLAG & (~0x0F00)) | graph::HAS_COO>
      CooT;

  cudaError_t retval = cudaSuccess;
  CooT coo;
  GUARD_CU(
      coo.Allocate(directed_graph.nodes, directed_graph.edges * 2, util::HOST));

#pragma omp parallel for
  for (auto e = 0; e < directed_graph.edges; e++) {
    VertexT src, dest;
    directed_graph.GetEdgeSrcDest(e, src, dest);
    coo.edge_pairs[e * 2].x = src;
    coo.edge_pairs[e * 2].y = dest;
    coo.edge_pairs[e * 2 + 1].x = dest;
    coo.edge_pairs[e * 2 + 1].y = src;
    if (FLAG & graph::HAS_EDGE_VALUES) {
      ValueT val = directed_graph.edge_values[e];
      coo.edge_values[e * 2] = val;
      coo.edge_values[e * 2 + 1] = val;
    }
  }

  if (FLAG & graph::HAS_NODE_VALUES) {
    for (auto v = 0; v < directed_graph.nodes; v++)
      coo.node_values[v] = directed_graph.node_values[v];
  }
  if (remove_duplicate_edges) {
    GUARD_CU(
        coo.RemoveDuplicateEdges(graph::BY_ROW_ASCENDING, util::HOST, 0, true));
  }
  GUARD_CU(undirected_graph.FromCoo(coo, util::HOST, 0, false));
  GUARD_CU(coo.Release(util::HOST));
  return retval;
}

}  // namespace graphio
}  // namespace gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
