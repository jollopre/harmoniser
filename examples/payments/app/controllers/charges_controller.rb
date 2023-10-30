class ChargesController < ApplicationController
  def create
    Publishers::ChargesPublisher.succeeded({ foo: "bar" })
  end
end
