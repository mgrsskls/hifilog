module Image
  extend ActiveSupport::Concern

  def validate_image_content_type
    return unless image.attachment

    unless [
      'image/jpeg',
      'image/webp',
      'image/png',
      'image/gif'
    ].include?(image.attachment.blob.content_type)
      errors.add(:image_content_type, 'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.')
    end
  end

  def validate_image_file_size
    return unless image.attachment
    return if image.attachment.blob.byte_size < 5_000_000

    errors.add(:image_file_size, 'is too big. Please use a file with a maximum of 5 MB.')
  end
end
