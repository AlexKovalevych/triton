defmodule TritonTest.Keyspaces.Default do
  @moduledoc false

  use Triton.Keyspace

  keyspace :default, conn: Triton.Conn, pool: Xandra.Cluster do
    with_options(replication: "{'class' : 'SimpleStrategy', 'replication_factor': 1}")
  end
end
