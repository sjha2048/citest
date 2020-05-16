# Based on http://github.com/Squeegy/rails-settings
#
# Copyright (c) 2006 Alex Wayne
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOa AND
# NONINFRINGEMENT. IN NO EVENT SaALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Settings < ActiveRecord::Base
  class SettingNotFound < RuntimeError; end

  belongs_to :target, polymorphic: true, required: false

  attr_encrypted :value, key: proc { Seek::Config.attr_encrypted_key }, marshal: true, marsheler: YAML
  before_save :ensure_no_plaintext, if: :encrypt?

  # Support old plugin
  if defined?(SettingsDefaults::DEFAULTS)
    @@defaults = SettingsDefaults::DEFAULTS.with_indifferent_access
  end

  #destroy the specified settings record
  def self.destroy(var_name)
    var_name = var_name.to_s
    if self[var_name]
      fetch(var_name).destroy
      true
    else
      raise SettingNotFound, "Setting variable \"#{var_name}\" not found"
    end
  end

  def self.to_hash(starting_with=nil)
    vars = select(:var, :values)
    vars = vars.where("var LIKE ?", "'#{starting_with}%'") if starting_with

    result = HashWithIndifferentAccess.new
    vars.each do |record|
      result[record.var] = record.value
    end
  end

  #get a setting value by [] notation
  def self.[](var_name)
    fetch(var_name).try(:value)
  end

  #set a setting value by [] notation
  def self.[]=(var_name, value)
    var_name = var_name.to_s

    record = fetch(var_name) || new(var: var_name)
    record.value = value
    record.save!

    value
  end

  def self.merge!(var_name, hash_value)
    raise ArgumentError unless hash_value.is_a?(Hash)

    old_value = self[var_name] || {}
    raise TypeError, "Existing value is not a hash, can't merge!" unless old_value.is_a?(Hash)

    new_value = old_value.with_indifferent_access.merge(hash_value)
    self[var_name] = new_value

    new_value
  end

  #get the value field, YAML decoded
  alias_method :attr_enc_value, :value
  def value
    if encrypted?
      attr_enc_value
    elsif self[:value].present?
      YAML::load(self[:value])
    else
      nil
    end
  end

  #set the value field, YAML encoded
  alias_method :attr_enc_value=, :value=
  def value=(new_value)
    if encrypt?
      self.attr_enc_value = new_value
    else
      self[:value] = new_value.to_yaml
    end
  end

  def self.fetch(var_name)
    where(var: var_name.to_s).first
  end

  def self.global
    where(target_type: nil, target_id: nil)
  end

  def self.for(target)
    where(target_type: target.class.name, target_id: target.id)
  end

  # Is this setting encrypted? - To handle settings that existed before encryption was introduced
  def encrypted?
    self[:encrypted_value].present?
  end

  # Should this setting be encrypted?
  def encrypt?
    Seek::Config.encrypted_setting?(self.var)
  end

  def self.defaults
    if (defined? @@defaults) && @@defaults
      @@defaults
    else
      @@defaults = {}.with_indifferent_access
      load_seek_config_defaults!
      defaults
    end
  end

  private

  def ensure_no_plaintext
    self[:value] = nil if encrypted_value_changed?
  end
end
