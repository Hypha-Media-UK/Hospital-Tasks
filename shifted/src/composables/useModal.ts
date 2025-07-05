import { ref, nextTick } from 'vue'

export interface UseModalOptions {
  onOpen?: () => void | Promise<void>
  onClose?: () => void | Promise<void>
  autoFocus?: boolean
  focusSelector?: string
}

export function useModal(options: UseModalOptions = {}) {
  const isOpen = ref(false)
  const isLoading = ref(false)

  const open = async () => {
    isOpen.value = true

    if (options.onOpen) {
      await options.onOpen()
    }

    if (options.autoFocus !== false) {
      await nextTick()

      if (options.focusSelector) {
        const element = document.querySelector(options.focusSelector) as HTMLElement
        element?.focus()
      }
    }
  }

  const close = async () => {
    if (options.onClose) {
      await options.onClose()
    }

    isOpen.value = false
  }

  const toggle = async () => {
    if (isOpen.value) {
      await close()
    } else {
      await open()
    }
  }

  const setLoading = (loading: boolean) => {
    isLoading.value = loading
  }

  return {
    isOpen,
    isLoading,
    open,
    close,
    toggle,
    setLoading
  }
}

// Specific modal composables for common patterns
export function useFormModal<T = any>(options: UseModalOptions & {
  initialData?: () => T
  onSubmit?: (data: T) => void | Promise<void>
  onReset?: () => void
} = {}) {
  const modal = useModal(options)
  const formData = ref<T>()
  const isSubmitting = ref(false)

  const openWithData = async (data?: T) => {
    if (data) {
      formData.value = data
    } else if (options.initialData) {
      formData.value = options.initialData()
    }

    await modal.open()
  }

  const submit = async (data: T) => {
    if (options.onSubmit) {
      isSubmitting.value = true
      try {
        await options.onSubmit(data)
        await modal.close()
      } finally {
        isSubmitting.value = false
      }
    }
  }

  const reset = () => {
    if (options.onReset) {
      options.onReset()
    }

    if (options.initialData) {
      formData.value = options.initialData()
    }
  }

  return {
    ...modal,
    formData,
    isSubmitting,
    openWithData,
    submit,
    reset
  }
}

export function useConfirmModal(options: {
  title?: string
  message?: string
  confirmText?: string
  cancelText?: string
  onConfirm?: () => void | Promise<void>
} = {}) {
  const modal = useModal()
  const isConfirming = ref(false)

  const confirm = async () => {
    if (options.onConfirm) {
      isConfirming.value = true
      try {
        await options.onConfirm()
        await modal.close()
      } finally {
        isConfirming.value = false
      }
    }
  }

  return {
    ...modal,
    isConfirming,
    confirm,
    title: options.title || 'Confirm Action',
    message: options.message || 'Are you sure you want to proceed?',
    confirmText: options.confirmText || 'Confirm',
    cancelText: options.cancelText || 'Cancel'
  }
}
