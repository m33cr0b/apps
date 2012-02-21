class BaseParser
  @@turn_on_debugging = true
  
  def debug message
    if @@turn_on_debugging
      puts message
    end
  end
end