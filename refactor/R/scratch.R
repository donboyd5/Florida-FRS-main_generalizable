
ns(pendata::frs)
tmp <- pendata::frs$params_env
ns(tmp) |> str_subset("cal")
ns(tmp) |> str_subset("constant")
tmp$constants_assumptions

constants_tbl <- tmp$constants_assumptions_tbl
