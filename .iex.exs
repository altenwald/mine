import_if_available(Mine)

if function_exported?(Mine, :start, 0), do: Mine.start()
