defmodule CodeStats.User.Machine do
  use Ecto.Schema

  import Ecto.Changeset

  schema "machines" do
    field(:name, :string)
    field(:api_salt, :string)
    field(:active, :boolean)

    belongs_to(:user, CodeStats.User)
    has_many(:pulses, CodeStats.User.Pulse)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Maximum length of machine's name.
  """
  def machine_name_max_length(), do: 64

  @doc """
  Creates a changeset based on the `data` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(data, params \\ %{}) do
    data
    |> cast(params, [:name])
    |> name_validations()
    |> put_change(:api_salt, generate_api_salt())
    |> validate_length(:api_salt, min: 1, max: 255)
    |> put_change(:active, true)
  end

  def update_changeset(data, params \\ %{}) do
    data
    |> cast(params, [:name])
    |> name_validations()
  end

  def activation_changeset(data, params \\ %{}) do
    data
    |> cast(params, [:active])
  end

  @doc """
  Creates a changeset to regenerate the API salt of the Machine.

  Takes no input.
  """
  def api_changeset(data) do
    data
    |> change(%{api_salt: generate_api_salt()})
  end

  defp name_validations(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: machine_name_max_length())
    |> unique_constraint(:name, name: :machines_name_user_id_index)
  end

  defp generate_api_salt() do
    Bcrypt.gen_salt(Application.get_env(:comeonin, :bcrypt_log_rounds))
  end
end
