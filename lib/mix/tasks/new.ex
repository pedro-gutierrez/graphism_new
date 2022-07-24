defmodule Mix.Tasks.Graphism.New do
  use Mix.Task

  import Mix.Generator

  @shortdoc "Creates a new Graphism project"

  @moduledoc """
  Creates a new Elixir project.
  It expects the path of the project as argument.

      mix graphism.new PATH [--app APP] [--module MODULE]

  A project at the given PATH will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  An `--app` option can be given in order to
  name the OTP application for the project.

  A `--module` option can be given in order
  to name the modules in the generated code skeleton.

  ## Examples

      mix graphism.new hello_world

  Is equivalent to:

      mix graphism.new hello_world --module HelloWorld

  """

  @switches [
    app: :string,
    module: :string
  ]

  @impl true
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] ->
        Mix.raise("Expected PATH to be given, please use \"mix new PATH\"")

      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !opts[:app])
        mod = opts[:module] || Macro.camelize(app)
        check_mod_name_validity!(mod)
        check_mod_name_availability!(mod)

        unless path == "." do
          check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd!(path, fn ->
          generate(app, mod, path)
        end)
    end
  end

  defp generate(app, mod, path) do
    assigns = [
      app: app,
      mod: mod,
      sup_app: sup_app(mod),
      version: get_version(System.version())
    ]

    mod_filename = Macro.underscore(mod)

    create_file("README.md", readme_template(assigns))
    create_file(".formatter.exs", formatter_template(assigns))
    create_file(".gitignore", gitignore_template(assigns))
    create_file("mix.exs", mix_exs_template(assigns))

    create_directory("config")
    create_file("config/config.exs", config_template(assigns))
    create_file("config/runtime.exs", runtime_config_template(assigns))

    create_directory("lib")
    create_file("lib/#{mod_filename}/application.ex", lib_app_template(assigns))
    create_file("lib/#{mod_filename}/repo.ex", lib_repo_template(assigns))
    create_file("lib/#{mod_filename}/auth.ex", lib_auth_template(assigns))
    create_file("lib/#{mod_filename}/port.ex", lib_port_template(assigns))
    create_file("lib/#{mod_filename}/router.ex", lib_router_template(assigns))
    create_file("lib/#{mod_filename}/schema.ex", lib_schema_template(assigns))

    create_directory("test")
    create_file("test/test_helper.exs", test_helper_template(assigns))
    create_file("test/#{mod_filename}_test.exs", test_template(assigns))

    """

    Your Mix project was created successfully.

    You can use "mix" to compile it:

        #{cd_path(path)}mix deps.get
        mix compile

    Then initialise your database:

        mix graphism.migrations
        mix ecto.create 
        mix ecto.migrate

    Finally, you can test with "mix test".

    Run "mix help" for more commands.

    To start your project: "iex -S mix". 

    Check the GraphiQL UI at http://localhost:4001/graphiql.
    Documentation for your REST Api is at http://localhost:4001/doc.
    """
    |> String.trim_trailing()
    |> Mix.shell().info()
  end

  defp sup_app(mod), do: ",\n      mod: {#{mod}.Application, []}"

  defp cd_path("."), do: ""
  defp cd_path(path), do: "cd #{path}\n    "

  defp check_application_name!(name, inferred?) do
    unless name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise(
        "Application name must start with a lowercase ASCII letter, followed by " <>
          "lowercase ASCII letters, numbers, or underscores, got: #{inspect(name)}" <>
          if inferred? do
            ". The application name is inferred from the path, if you'd like to " <>
              "explicitly name the application then use the \"--app APP\" option"
          else
            ""
          end
      )
    end
  end

  defp check_mod_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise(
        "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect(name)}"
      )
    end
  end

  defp check_mod_name_availability!(name) do
    name = Module.concat(Elixir, name)

    if Code.ensure_loaded?(name) do
      Mix.raise("Module name #{inspect(name)} is already taken, please choose another name")
    end
  end

  defp check_directory_existence!(path) do
    msg = "The directory #{inspect(path)} already exists. Are you sure you want to continue?"

    if File.dir?(path) and not Mix.shell().yes?(msg) do
      Mix.raise("Please select another directory for installation")
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)

    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        [] -> ""
      end
  end

  embed_template(:readme, """
  # <%= @mod %>

  **TODO: Add description**
  <%= if @app do %>
  ## Installation

  If [available in Hex](https://hex.pm/docs/publish), the package can be installed
  by adding `<%= @app %>` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:<%= @app %>, "~> 0.1.0"}
    ]
  end
  ```

  Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
  and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
  be found at [https://hexdocs.pm/<%= @app %>](https://hexdocs.pm/<%= @app %>).
  <% end %>
  """)

  embed_template(:formatter, """
  # Used by "mix format"
  [
    inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
  ]
  """)

  embed_template(:gitignore, """
  /_build/
  /cover/
  /deps/
  /doc/
  /.fetch
  erl_crash.dump
  *.ez
  <%= @app %>-*.tar
  /tmp/
  """)

  embed_template(:mix_exs, """
  defmodule <%= @mod %>.MixProject do
    use Mix.Project

    def project do
      [
        app: :<%= @app %>,
        version: "0.1.0",
        elixir: "~> <%= @version %>",
        start_permanent: Mix.env() == :prod,
        deps: deps()
      ]
    end

    # Run "mix help compile.app" to learn about applications.
    def application do
      [
        extra_applications: [:graphism]<%= @sup_app %>
      ]
    end

    # Run "mix help deps" to learn about dependencies.
    defp deps do
      [
        {:graphism, git: "https://github.com/gravity-core/graphism.git", tag: "v0.8.0"}
      ]
    end
  end
  """)

  embed_template(:lib_app, """
  defmodule <%= @mod %>.Application do
    @moduledoc false

    use Application

    @impl true
    def start(_type, _args) do
      children = [
        <%= @mod %>.Repo,
        <%= @mod %>.Port
      ]

      opts = [strategy: :one_for_one, name: <%= @mod %>.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  """)

  embed_template(:lib_repo, """
  defmodule <%= @mod %>.Repo do
    @moduledoc false
    use Ecto.Repo, otp_app: :<%= @app %>, adapter: Ecto.Adapters.Postgres
  end
  """)

  embed_template(:lib_auth, """
  defmodule <%= @mod %>.Auth do
    @moduledoc false
    
    def allow?(_args, _context), do: true
    def scope(query, _context), do: query
  end
  """)

  embed_template(:lib_port, """
  defmodule <%= @mod %>.Port do
    @moduledoc false

    def child_spec(_) do
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: <%= @mod %>.Router,
        options: [port: System.get_env("PORT", "4001") |> String.to_integer()]
      )
    end
  end
  """)

  embed_template(:lib_router, """
  defmodule <%= @mod %>.Router do
    @moduledoc false
    use Plug.Router

    plug(Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      pass: ["*/*"],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    forward("/graphql", to: Absinthe.Plug, init_opts: [schema: <%= @mod %>.Schema])
    forward("/api", to: Blog.Schema.Router)
    
    if Mix.env() == :dev do
      forward("/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: <%= @mod %>.Schema,
          default_url: "/api/graphql"
        ]
      )
      get("/doc", to: <%= @mod %>.Schema.RedocUI, init_opts: [spec_url: "/api/openapi.json"])
    end

    get "/health" do
      send_resp(conn, 200, "")
    end

    match _ do
      send_resp(conn, 404, "")
    end
  end
  """)

  embed_template(:lib_schema, """
  defmodule <%= @mod %>.Schema do
    @moduledoc false
    use Graphism, repo: <%= @mod %>.Repo
    
    allow(<%= @mod %>.Auth)

    entity :user do
      unique(string(:email))

      action(:list)
      action(:create)
      action(:update)
      action(:delete)
    end
  end
  """)

  embed_template(:test, """
  defmodule <%= @mod %>Test do
    use ExUnit.Case
  end
  """)

  embed_template(:test_helper, """
  ExUnit.start()
  """)

  embed_template(:config, """
  import Config

  config :<%= @app %>, ecto_repos: [<%= @mod %>.Repo]
  config :graphism, schema: <%= @mod %>.Schema
  """)

  embed_template(:runtime_config, """
  import Config

  config :<%= @app %>, <%= @mod %>.Repo, database: "<%= @app %>"
  """)
end
