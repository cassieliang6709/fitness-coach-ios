using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [
    (name = "main", worker = .mainWorker),
  ],

  sockets = [
    # Serve HTTP on port 8788
    ( name = "http",
      address = "0.0.0.0:8788",
      http = (),
      service = "main"
    ),
  ]
);

const mainWorker :Workerd.Worker = (
  serviceWorkerScript = embed "dist/index.js",
  compatibilityDate = "2025-11-01",
  compatibilityFlags = ["nodejs_compat"],
);
