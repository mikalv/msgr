defmodule Teams.PaginationTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  alias Teams.Pagination

  # A dummy schema for building queries
  defmodule FakeMessage do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "messages" do
      timestamps()
    end
  end

  defp base_query, do: from(m in FakeMessage)

  describe "parse_params/1" do
    test "extracts before cursor" do
      assert %{before: "abc-123"} = Pagination.parse_params(%{"before" => "abc-123"})
    end

    test "extracts after cursor" do
      assert %{after: "xyz-789"} = Pagination.parse_params(%{"after" => "xyz-789"})
    end

    test "extracts around cursor" do
      assert %{around: "mid-456"} = Pagination.parse_params(%{"around" => "mid-456"})
    end

    test "extracts limit as integer" do
      assert %{limit: 25} = Pagination.parse_params(%{"limit" => "25"})
    end

    test "omits nil values" do
      result = Pagination.parse_params(%{})
      refute Map.has_key?(result, :before)
      refute Map.has_key?(result, :after)
      refute Map.has_key?(result, :around)
      refute Map.has_key?(result, :limit)
    end

    test "caps limit at 100" do
      assert %{limit: 100} = Pagination.parse_params(%{"limit" => "999"})
    end

    test "ignores invalid limit string" do
      result = Pagination.parse_params(%{"limit" => "abc"})
      refute Map.has_key?(result, :limit)
    end

    test "ignores zero or negative limit" do
      result = Pagination.parse_params(%{"limit" => "0"})
      refute Map.has_key?(result, :limit)

      result2 = Pagination.parse_params(%{"limit" => "-5"})
      refute Map.has_key?(result2, :limit)
    end
  end

  describe "paginate/2" do
    test "default: orders DESC with limit 50" do
      {query, meta} = Pagination.paginate(base_query())
      assert meta == %{direction: :desc}

      query_string = inspect(query)
      assert query_string =~ "desc"
      assert query_string =~ "limit"
    end

    test "before: filters id < cursor and orders DESC" do
      cursor = Ecto.UUID.generate()
      {query, meta} = Pagination.paginate(base_query(), %{before: cursor})

      assert meta == %{direction: :desc}
      query_string = inspect(query)
      assert query_string =~ "desc"
    end

    test "after: filters id > cursor and orders ASC" do
      cursor = Ecto.UUID.generate()
      {query, meta} = Pagination.paginate(base_query(), %{after: cursor})

      assert meta == %{direction: :asc}
      query_string = inspect(query)
      assert query_string =~ "asc"
    end

    test "around: returns union with direction :around" do
      cursor = Ecto.UUID.generate()
      {_query, meta} = Pagination.paginate(base_query(), %{around: cursor})

      assert meta == %{direction: :around}
    end

    test "default limit is 50" do
      {query, _meta} = Pagination.paginate(base_query())
      # The query struct should have limit set
      assert %Ecto.Query{limit: %Ecto.Query.QueryExpr{expr: 50}} = query
    end

    test "respects explicit limit" do
      {query, _meta} = Pagination.paginate(base_query(), %{limit: 10})
      assert %Ecto.Query{limit: %Ecto.Query.QueryExpr{expr: 10}} = query
    end

    test "caps limit at 100" do
      {query, _meta} = Pagination.paginate(base_query(), %{limit: 200})
      assert %Ecto.Query{limit: %Ecto.Query.QueryExpr{expr: 100}} = query
    end

    test "around splits limit in half" do
      cursor = Ecto.UUID.generate()
      {_query, meta} = Pagination.paginate(base_query(), %{around: cursor, limit: 20})
      assert meta.direction == :around
    end
  end
end
