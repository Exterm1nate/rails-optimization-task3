class Trip < ApplicationRecord
  HHMM_REGEXP = /([0-1][0-9]|[2][0-3]):[0-5][0-9]/

  belongs_to :from, class_name: 'City'
  belongs_to :to, class_name: 'City'
  belongs_to :bus

  validates :from, presence: true
  validates :to, presence: true
  validates :bus, presence: true

  validates :start_time, format: { with: HHMM_REGEXP, message: 'Invalid time' }
  validates :duration_minutes, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :price_cents, presence: true
  validates :price_cents, numericality: { greater_than: 0 }

  def arrival_time
    (Time.strptime(start_time, '%R') + duration_minutes.minutes).strftime('%H:%M')
  end

  def travel_time
    @travel_time ||= duration_minutes.divmod(60)
  end

  def prices
    @prices ||= price_cents.divmod(100)
  end

  def to_h
    {
      from: from.name,
      to: to.name,
      start_time: start_time,
      duration_minutes: duration_minutes,
      price_cents: price_cents,
      bus: {
        number: bus.number,
        model: bus.model,
        services: bus.services.map(&:name),
      },
    }
  end
end
