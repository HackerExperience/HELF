defmodule HE.Error do
  
  def format_reply(error, code, msg) do
    {code, msg}
  end

  def format_reply(error, msg \\ "") do
    case error do
      :unauthorized ->
        {401, msg}
      :not_found ->
        {404, msg}
      :internal ->
        {500, msg}
      _ ->
        {500, "Something went wrong"}
    end
  end

end
