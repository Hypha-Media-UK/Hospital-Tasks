import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import BaseModal from '../../components/shared/BaseModal.vue'

describe('BaseModal', () => {
  let wrapper

  beforeEach(() => {
    // Mock document.addEventListener and removeEventListener
    vi.spyOn(document, 'addEventListener')
    vi.spyOn(document, 'removeEventListener')
  })

  afterEach(() => {
    if (wrapper) {
      wrapper.unmount()
    }
    vi.restoreAllMocks()
  })

  it('should render with default props', () => {
    wrapper = mount(BaseModal, {
      slots: {
        default: '<p>Modal content</p>'
      }
    })

    expect(wrapper.find('.modal-overlay').exists()).toBe(true)
    expect(wrapper.find('.modal-container--medium').exists()).toBe(true)
    expect(wrapper.text()).toContain('Modal content')
  })

  it('should render title and subtitle', () => {
    wrapper = mount(BaseModal, {
      props: {
        title: 'Test Modal',
        subtitle: 'Test subtitle'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-title').text()).toBe('Test Modal')
    expect(wrapper.find('.modal-subtitle').text()).toBe('Test subtitle')
  })

  it('should apply size classes correctly', () => {
    wrapper = mount(BaseModal, {
      props: {
        size: 'large'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-container--large').exists()).toBe(true)
  })

  it('should apply full height class when specified', () => {
    wrapper = mount(BaseModal, {
      props: {
        fullHeight: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-container--full-height').exists()).toBe(true)
  })

  it('should hide header when hideHeader is true', () => {
    wrapper = mount(BaseModal, {
      props: {
        hideHeader: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-header').exists()).toBe(false)
  })

  it('should hide close button when hideCloseButton is true', () => {
    wrapper = mount(BaseModal, {
      props: {
        hideCloseButton: true,
        title: 'Test'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-close-button').exists()).toBe(false)
  })

  it('should apply no padding class when noPadding is true', () => {
    wrapper = mount(BaseModal, {
      props: {
        noPadding: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-body--no-padding').exists()).toBe(true)
  })

  it('should emit close event when close button is clicked', async () => {
    wrapper = mount(BaseModal, {
      props: {
        title: 'Test Modal'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    await wrapper.find('.modal-close-button').trigger('click')
    expect(wrapper.emitted('close')).toBeTruthy()
  })

  it('should emit close event when overlay is clicked and closeOnOverlay is true', async () => {
    wrapper = mount(BaseModal, {
      props: {
        closeOnOverlay: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    await wrapper.find('.modal-overlay').trigger('click')
    expect(wrapper.emitted('close')).toBeTruthy()
  })

  it('should not emit close event when overlay is clicked and closeOnOverlay is false', async () => {
    wrapper = mount(BaseModal, {
      props: {
        closeOnOverlay: false
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    await wrapper.find('.modal-overlay').trigger('click')
    expect(wrapper.emitted('close')).toBeFalsy()
  })

  it('should render header actions slot', () => {
    wrapper = mount(BaseModal, {
      props: {
        title: 'Test Modal'
      },
      slots: {
        default: '<p>Content</p>',
        'header-actions': '<button class="custom-action">Custom Action</button>'
      }
    })

    expect(wrapper.find('.custom-action').exists()).toBe(true)
    expect(wrapper.find('.custom-action').text()).toBe('Custom Action')
  })

  it('should render footer slot', () => {
    wrapper = mount(BaseModal, {
      slots: {
        default: '<p>Content</p>',
        footer: '<button class="footer-button">Footer Button</button>'
      }
    })

    expect(wrapper.find('.modal-footer').exists()).toBe(true)
    expect(wrapper.find('.footer-button').exists()).toBe(true)
  })

  it('should not render footer when no footer slot is provided', () => {
    wrapper = mount(BaseModal, {
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(wrapper.find('.modal-footer').exists()).toBe(false)
  })

  it('should add escape key listener when closeOnEscape is true', () => {
    wrapper = mount(BaseModal, {
      props: {
        closeOnEscape: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(document.addEventListener).toHaveBeenCalledWith('keydown', expect.any(Function))
  })

  it('should not add escape key listener when closeOnEscape is false', () => {
    wrapper = mount(BaseModal, {
      props: {
        closeOnEscape: false
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    expect(document.addEventListener).not.toHaveBeenCalledWith('keydown', expect.any(Function))
  })

  it('should remove escape key listener on unmount', () => {
    wrapper = mount(BaseModal, {
      props: {
        closeOnEscape: true
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    wrapper.unmount()

    expect(document.removeEventListener).toHaveBeenCalledWith('keydown', expect.any(Function))
  })

  it('should validate size prop', () => {
    // This test checks that invalid sizes are rejected
    const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    
    wrapper = mount(BaseModal, {
      props: {
        size: 'invalid-size'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    // Vue should warn about invalid prop value
    expect(consoleWarn).toHaveBeenCalled()
    
    consoleWarn.mockRestore()
  })

  it('should use custom close button label', () => {
    wrapper = mount(BaseModal, {
      props: {
        title: 'Test Modal',
        closeButtonLabel: 'Custom Close'
      },
      slots: {
        default: '<p>Content</p>'
      }
    })

    const closeButton = wrapper.find('.modal-close-button')
    expect(closeButton.attributes('aria-label')).toBe('Custom Close')
  })
})
