class String
  def add_scheme
    unless self.match(/^http/)
      "http://#{self}"
    else
      self
    end
  end

  def good?
    to_i < 300
  end
end
