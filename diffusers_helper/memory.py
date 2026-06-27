# By lllyasviel


import platform
import torch


cpu = torch.device('cpu')

if torch.cuda.is_available():
    gpu = torch.device(f'cuda:{torch.cuda.current_device()}')
elif torch.backends.mps.is_available():
    gpu = torch.device('mps')
else:
    gpu = torch.device('cpu')

gpu_complete_modules = []


class DynamicSwapInstaller:
    @staticmethod
    def _install_module(module: torch.nn.Module, **kwargs):
        original_class = module.__class__
        module.__dict__['forge_backup_original_class'] = original_class

        def hacked_get_attr(self, name: str):
            if '_parameters' in self.__dict__:
                _parameters = self.__dict__['_parameters']
                if name in _parameters:
                    p = _parameters[name]
                    if p is None:
                        return None
                    if p.__class__ == torch.nn.Parameter:
                        return torch.nn.Parameter(p.to(**kwargs), requires_grad=p.requires_grad)
                    else:
                        return p.to(**kwargs)
            if '_buffers' in self.__dict__:
                _buffers = self.__dict__['_buffers']
                if name in _buffers:
                    return _buffers[name].to(**kwargs)
            return super(original_class, self).__getattr__(name)

        module.__class__ = type('DynamicSwap_' + original_class.__name__, (original_class,), {
            '__getattr__': hacked_get_attr,
        })

        return

    @staticmethod
    def _uninstall_module(module: torch.nn.Module):
        if 'forge_backup_original_class' in module.__dict__:
            module.__class__ = module.__dict__.pop('forge_backup_original_class')
        return

    @staticmethod
    def install_model(model: torch.nn.Module, **kwargs):
        # On MPS (Apple Silicon), dynamic swapping is unnecessary
        # because unified memory architecture handles page migration transparently.
        # Skip the hook to avoid the overhead of __getattr__ interception.
        device = kwargs.get('device', None)
        if device is not None and getattr(device, 'type', None) == 'mps':
            model.to(device=device)
            return
        for m in model.modules():
            DynamicSwapInstaller._install_module(m, **kwargs)
        return

    @staticmethod
    def uninstall_model(model: torch.nn.Module):
        for m in model.modules():
            DynamicSwapInstaller._uninstall_module(m)
        return


def fake_diffusers_current_device(model: torch.nn.Module, target_device: torch.device):
    if hasattr(model, 'scale_shift_table'):
        model.scale_shift_table.data = model.scale_shift_table.data.to(target_device)
        return

    for k, p in model.named_modules():
        if hasattr(p, 'weight'):
            p.to(target_device)
            return


def get_cuda_free_memory_gb(device=None):
    if device is None:
        device = gpu

    if device.type != 'cuda' or not torch.cuda.is_available():
        # On Mac with unified memory, report ~75% of system RAM as "available"
        # This allows the high-vram threshold (60GB) to be reached only on
        # machines with >=80GB RAM, letting low-VRAM paths activate otherwise.
        try:
            import psutil
            total_gb = psutil.virtual_memory().total / (1024 ** 3)
            return total_gb * 0.75
        except ImportError:
            return 8.0

    memory_stats = torch.cuda.memory_stats(device)
    bytes_active = memory_stats['active_bytes.all.current']
    bytes_reserved = memory_stats['reserved_bytes.all.current']
    bytes_free_cuda, _ = torch.cuda.mem_get_info(device)
    bytes_inactive_reserved = bytes_reserved - bytes_active
    bytes_total_available = bytes_free_cuda + bytes_inactive_reserved
    return bytes_total_available / (1024 ** 3)


def move_model_to_device_with_memory_preservation(model, target_device, preserved_memory_gb=0):
    print(f'Moving {model.__class__.__name__} to {target_device} with preserved memory: {preserved_memory_gb} GB')

    for m in model.modules():
        if target_device.type == 'cuda' and get_cuda_free_memory_gb(target_device) <= preserved_memory_gb:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            return

        if hasattr(m, 'weight'):
            m.to(device=target_device)

    model.to(device=target_device)
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    return


def offload_model_from_device_for_memory_preservation(model, target_device, preserved_memory_gb=0):
    print(f'Offloading {model.__class__.__name__} from {target_device} to preserve memory: {preserved_memory_gb} GB')

    for m in model.modules():
        if target_device.type == 'cuda' and get_cuda_free_memory_gb(target_device) >= preserved_memory_gb:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            return

        if hasattr(m, 'weight'):
            m.to(device=cpu)

    model.to(device=cpu)
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    return


def unload_complete_models(*args):
    for m in gpu_complete_modules + list(args):
        m.to(device=cpu)
        print(f'Unloaded {m.__class__.__name__} as complete.')

    gpu_complete_modules.clear()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    return


def get_optimal_dtype():
    """Return the best dtype for the current device.
    
    - CUDA: bfloat16 (native support, best performance)
    - MPS: float16 (wider hardware support on M1/M2, bfloat16 may fall back to software)
    - CPU: float32 (bfloat16/float16 have no performance benefit)
    """
    if torch.cuda.is_available():
        return torch.bfloat16
    elif torch.backends.mps.is_available():
        return torch.float16
    else:
        return torch.float32


def load_model_as_complete(model, target_device, unload=True):
    if unload:
        unload_complete_models()

    model.to(device=target_device)
    print(f'Loaded {model.__class__.__name__} to {target_device} as complete.')

    gpu_complete_modules.append(model)
    return
