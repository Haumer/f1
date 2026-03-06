class Circuit < ApplicationRecord
    has_many :races

    validates :name, :circuit_ref, presence: true
    validates :circuit_ref, uniqueness: true

    def to_param
        circuit_ref
    end

    def track_image_path
        "circuits/#{circuit_ref}.svg"
    end

    def track_image?
        Rails.application.assets_manifest&.find_sources(track_image_path)&.any? ||
            Rails.root.join("app/assets/images", track_image_path).exist?
    end
end
