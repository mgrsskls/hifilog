module Image
  extend ActiveSupport::Concern

  def validate_image_content_type
    return unless images.attached?

    images.each do |img|
      if [
        'image/jpeg',
        'image/webp',
        'image/png',
        'image/gif'
      ].include?(img.blob.content_type)
        next
      end

      errors.add(:image_content_type, 'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.')
    end
  end

  def validate_image_file_size
    return unless images.attached?

    images.each do |img|
      next if img.blob.byte_size < 10_000_000

      errors.add(:image_file_size, 'is too big. Please use a file with a maximum of 10 MB.')
    end
  end
end
