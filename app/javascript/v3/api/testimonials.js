import wootConstants from 'dashboard/constants/globals';
import wootAPI from './apiClient';

export const getTestimonialContent = () => {
  if (!wootConstants.TESTIMONIAL_URL) return Promise.resolve({ data: [] });
  return wootAPI.get(wootConstants.TESTIMONIAL_URL);
};
