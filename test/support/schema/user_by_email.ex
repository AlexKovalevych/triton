defmodule TritonTest.Schema.UserByEmail do
  use Triton.Schema

  materialized_view :users_by_email, from: TritonTest.Schema.User do
    fields([
      :id,
      :email
    ])

    partition_key([:email])
    cluster_columns([:id])

    with_options(
      gc_grace_seconds: 172_800,
      clustering_order_by: [
        email: :asc,
        user_id: :desc
      ]
    )
  end
end
