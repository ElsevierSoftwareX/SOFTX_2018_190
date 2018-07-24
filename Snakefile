import os
import csv
from math import sqrt
from collections import defaultdict
from operator import itemgetter
from datetime import timedelta


def atom_charge(symbol):
    periodic = ['X', 'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne']
    periodic += ['Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar']
    periodic += ['K', 'Ca', 'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr']
    periodic += ['Rb', 'Sr', 'Y', 'Zr', 'Nb', 'Mo', 'Tc', 'Ru', 'Rh', 'Pd', 'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I', 'Xe']
    periodic += ['Cs', 'Ba', 'La', 'Hf', 'Ta', 'W', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg', 'Tl', 'Pb', 'Bi', 'Po', 'At', 'Rn']
    periodic += ['Fr', 'Ra', 'Ac', 'Rf', 'Db', 'Sg', 'Bh', 'Hs']
    periodic[58:58] = ['Ce', 'Pr', 'Nd', 'Pm', 'Sm', 'Eu', 'Gd', 'Tb', 'Dy', 'Ho', 'Er', 'Tm', 'Yb', 'Lu']
    periodic[90:90] = ['Th', 'Pa', 'U', 'Np', 'Pu', 'Am', 'Cm', 'Bk', 'Cf', 'Es', 'Fm', 'Md', 'No', 'Lr']
    atoms = {v.lower():i for i,v in enumerate(periodic)}
    return atoms[symbol.lower()]

def get_atomic_symbols(molecule):
    """Get atomic symbols set"""
    with open(os.path.join('..', 'chem_database', molecule + '.xyz'), 'r') as input_geometry:
        natoms = int(input_geometry.readline())
        charge, mult = map(int, input_geometry.readline().split())
        atomic_symbols = set()
        for atom in range(natoms):
            symbol, x, y, z = input_geometry.readline().split()
            atomic_symbols.add(symbol)
    return atomic_symbols

def get_XYZ(molecule):
    """Load XYZ-geometry from file."""
    with open(os.path.join('..', 'chem_database', molecule + '.xyz'), 'r') as input_geometry:
        natoms = int(input_geometry.readline())
        charge, mult = map(int, input_geometry.readline().split())
        geometry = []
        for atom in range(natoms):
            symbol, x, y, z = input_geometry.readline().split()
            geometry.append((atom_charge(symbol), map(float, (x, y, z))))
    return geometry

def get_max_Z(molecule):
    """Get maximal Z for atoms in molecule."""
    return max(Z for Z, _ in get_XYZ(molecule))

def get_lebel_set(molecule):
    """Get set of lebels from xyz-file for every atom type"""
    with open(os.path.join('..', 'chem_database', molecule + '.xyz'), 'r') as input_geometry:
        natoms = int(input_geometry.readline())
        charge, mult = map(int, input_geometry.readline().split())
        atomic_symbols = []
        for atom in range(natoms):
            symbol, x, y, z = input_geometry.readline().split()
            atomic_symbols.append(symbol)

    result = defaultdict(list)
    for i, item in enumerate(atomic_symbols):
        result[item].append(i+1)
    return result

def get_ae_cutoffs(molecule):
    """Create AE_cutoff initial values.
    Used for Backflow format.
    """
    result = []
    for i, _ in enumerate(get_XYZ(molecule)):
        result.append('{i}         {i}         0.5                          0'.format(i=i+1))
    return '\n  '.join(result)

def  casino_time(*path):
    """Get CASINO time.
     Total CASINO CPU time  : : :      378.0500
    """
    regexp = re.compile(' Total CASINO CPU time  : : :\s+(?P<energy_error>\d+\.\d+)')
    try:
        with open(os.path.join(*path, 'out'), 'r') as casino_out:
            # we are only interested in the last occurrence
            return float(re.findall(regexp, casino_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None

def vmc_energy(*path):
    """Get VMC energy without JASTROW optimisation.
     -152.988424660763 +/- 0.003047553900      Correlation time method
    """

    regexp = re.compile(' (?P<energy>[-+]?\d+\.\d+) \+/- (?P<energy_error>[-+]?\d+\.\d+)      Correlation time method')
    try:
        with open(os.path.join(*path, 'out'), 'r') as vmc_out:
            # we are only interested in the last occurrence
            return map(float, re.findall(regexp, vmc_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None, None

def vmc_variance(*path):
    """Get VMC variance with JASTROW optimisation.
      Sample variance of E_L (au^2/sim.cell) : 3.169677109628 +- 0.034986257092
    """

    regexp = re.compile('Sample variance of E_L \(au\^2/sim.cell\) : (?P<variance>[-+]?\d+\.\d+) \+- (?P<variance_error>[-+]?\d+\.\d+)')
    try:
        with open(os.path.join(*path, 'out'), 'r') as vmc_opt_out:
            # we are only interested in the last occurrence
            return map(float, re.findall(regexp, vmc_opt_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None, None

def dmc_energy(*path):
    """Get DMC energy.
          mean:   -153.795024411601 +/-       0.001346260888
    """

    dir = os.path.join(*path)
    try:
        open(os.path.join(dir, '.casino_finished'), 'r').close()
        regexp = re.compile('mean:\s+(?P<energy>[-+]?\d+\.\d+) \+/- \s+(?P<energy_error>[-+]?\d+\.\d+)')
        with open(os.path.join(dir, 'out'), 'r') as dmc_out:
            # we are only interested in the last occurrence
            return map(float, re.findall(regexp, dmc_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None, None

def dmc_stderr(*path):
    """Get DMC standard error.
          stderr:      0.000906128433 +/-       0.000046917552
    """

    dir = os.path.join(*path)
    try:
        open(os.path.join(dir, '.casino_finished'), 'r').close()
        regexp = re.compile('stderr:\s+(?P<energy>[-+]?\d+\.\d+) \+/- \s+(?P<energy_error>[-+]?\d+\.\d+)')
        with open(os.path.join(dir, 'out'), 'r') as dmc_out:
            # we are only interested in the last occurrence
            return map(float, re.findall(regexp, dmc_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None, None

def dmc_ncorr(*path):
    """Get DMC correlation N.
          N_corr:      0.000906128433 +/-       0.000046917552
    """

    dir = os.path.join(*path)
    try:
        open(os.path.join(dir, '.casino_finished'), 'r').close()
        regexp = re.compile('N_corr:\s+(?P<energy>[-+]?\d+\.\d+) \+/- \s+(?P<energy_error>[-+]?\d+\.\d+)')
        with open(os.path.join(dir, 'out'), 'r') as dmc_out:
            # we are only interested in the last occurrence
            return map(float, re.findall(regexp, dmc_out.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None, None

def dmc_stats_nstep(*path):
    """Get DMC statistic accumulation steps.
          dmc_stats_nstep   : 96000
    """

    dir = os.path.join(*path)
    try:
        regexp = re.compile('dmc_stats_nstep   :\s+(?P<nstep>\d+)')
        with open(os.path.join(dir, 'input'), 'r') as dmc_input:
            # we are only interested in the last occurrence
            return int(re.findall(regexp, dmc_input.read())[-1])
    except (FileNotFoundError, IndexError) as e:
        print(e)
        return None

def get_all_inputs():
    "get file names of all *.xyz input files"
    return sorted((os.path.splitext(filename)[0] for filename in os.listdir(config['INPUTS_DIR']) if os.path.splitext(filename)[1] == '.xyz'))


wildcard_constraints:
    i = '\d',
    molecule='[-\w+=.]+',
    method='[-\w()]+',
    basis='[-\w]+',
    jastrow_type='[_\w]+',
    jastrow_rank='[_\w]+',
    backflow_rank='[_\w]+',
    jastrow_opt_method='\w+',

####################################################################################################################

rule HF_RESULTS:
    output: 'hf_results.csv'
    run:
        with open(output[0], 'w', newline='') as result_file:
            energy_data = csv.writer(result_file, dialect=csv.unix_dialect, quoting=csv.QUOTE_NONE)
            fieldnames = [
                'method', 'basis', 'molecule', 'hf_energy', 'hf_time',
            ]
            energy_data.writerow(fieldnames)
            for method in METHODS:
                for basis in BASES:
                    for molecule in MOLECULES:
                        path = (method, basis, molecule)
                        try:
                            energy_data.writerow((
                                *path,
                                hf_energy(*path),
                                hf_time(*path),
                            ))
                        except (FileNotFoundError, IndexError) as e:
                            print(e)

rule RESULTS:
    output: 'results.csv'
    run:
        with open(output[0], 'w', newline='') as result_file:
            writer = csv.writer(result_file, dialect=csv.unix_dialect, quoting=csv.QUOTE_NONE)
            fieldnames = [
                'method', 'basis', 'molecule', 'hf_energy', 'hf_time',
                'jastrow_rank',
                'vmc_opt_energy', 'vmc_opt_energy_error', 'vmc_opt_variance', 'vmc_opt_variance_error', 'vmc_opt_time', 'vmc_opt_energy_time',
                'dmc_energy', 'dmc_energy_error', 'dmc_stderr', 'dmc_stderr_error', 'dmc_ncorr', 'dmc_ncorr_error', 'dmc_time'
            ]
            writer.writerow(fieldnames)
            vmc_path = ('VMC', '10000000')
            for method in METHODS:
                for basis in BASES:
                    for molecule in MOLECULES:
                        path = (method, basis, molecule)
                        for jastrow_rank in JASTROW_RANKS:
                            vmc_opt_path = ('VMC_OPT', 'emin', jastrow_rank, '10000')
                            vmc_opt_energy_path = ('VMC_OPT', 'emin', jastrow_rank, '1000000_9')
                            dmc_path = ('VMC_DMC', 'emin', jastrow_rank, 'tmax_2_1024_1')
                            try:
                                writer.writerow((
                                    *path,
                                    hf_energy(*path),
                                    hf_time(*path),
                                    jastrow_rank,
                                    *vmc_energy(*path, *vmc_opt_energy_path),
                                    *vmc_variance(*path, *vmc_opt_energy_path),
                                    casino_time(*path, *vmc_opt_path),
                                    casino_time(*path, *vmc_opt_energy_path),
                                    *dmc_energy(*path, *dmc_path),
                                    *dmc_stderr(*path, *dmc_path),
                                    *dmc_ncorr(*path, *dmc_path),
                                    casino_time(*path, *dmc_path),
                                ))
                            except (FileNotFoundError, IndexError) as e:
                                print(e)

rule VMC_DMC_RUN:
    input:      '{path}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/input',
                '{path}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/gwfn.data',
                '{path}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/parameters.casl',
    output:     '{path}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'


rule DMC_STATS_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_2/gwfn.data',
                '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_1/out',
                '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_2/config.in',
    output:     '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_2/input'
    params:
        dt_relative_step = 2.0,
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        stderr, _ = dmc_stderr(wildcards.method, wildcards.basis, wildcards.molecule, 'VMC_DMC', wildcards.jastrow_opt_method, wildcards.jastrow_rank, 'tmax_2_1024_1')
        dtdmc = 1.0/(get_max_Z(wildcards.molecule)**2 * 3.0 * params.dt_relative_step)
        if STD_ERR > stderr:
            nstep = 1
        else:
            nstep = ((stderr/STD_ERR)**2 - 1) * 50000
            nstep = max(10000, int(round(nstep, -4)))
        if wildcards.basis.endswith('_PP'):
            tmove = 'T'
        else:
            tmove = 'F'
        with open(output[0], 'w') as f:
            f.write(open('../dmc_stats.tmpl').read().format(
                neu=neu, ned=ned, nconfig=wildcards.nconfig, dtdmc=dtdmc, molecule=wildcards.molecule, nstep=nstep, nblock=nstep // 1000,
                tmove=tmove, backflow='F'
            ))

rule DMC_STATS_CONFIG:
    input:      '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_1/out',
    output:     '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_2/config.in'
    shell:      'cp "$(dirname "{input}")"/config.out "{output}"'

rule VMC_DMC_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_1/gwfn.data',
    output:     '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_1/input'
    params:
        dt_relative_step = 2.0,
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        dtdmc = 1.0/(get_max_Z(wildcards.molecule)**2 * 3.0 * params.dt_relative_step)
        nstep = 50000
        if wildcards.basis.endswith('_PP'):
            tmove = 'T'
        else:
            tmove = 'F'
        with open(output[0], 'w') as f:
            f.write(open('../vmc_dmc.tmpl').read().format(
                neu=neu, ned=ned, nconfig=wildcards.nconfig, dtdmc=dtdmc, molecule=wildcards.molecule, nstep=nstep, nblock=nstep // 1000,
                tmove=tmove, backflow='F'
            ))

rule VMC_DMC_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/10000/out'
    output:     '{method}/{basis}/{molecule}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/parameters.casl'
    run:
        shell('ln -s ../../../../VMC_OPT/{wildcards.jastrow_opt_method}/{wildcards.jastrow_rank}/10000/parameters.9.casl "{output}"')
        # workaround in multireference case
        shell('[[ -e "$(dirname "{input}")/correlation.out.9" ]] && ln -rs "$(dirname "{input}")/correlation.out.9" "$(dirname "{output}")/correlation.data"; exit 0')
        # workaround in pseudopotential
        if wildcards.basis.endswith('_PP'):
            for symbol in get_atomic_symbols(wildcards.molecule):
                symbol = symbol.lower()
                shell('cd "$(dirname "{output}")" && ln -s ../../../../../../../../ppotential/DiracFock_AREP/{symbol}_pp.data')


rule VMC_DMC_GWFN:
    input:      '{path}/gwfn.data',
    output:     '{path}/VMC_DMC/{jastrow_opt_method}/{jastrow_rank}/tmax_2_{nconfig}_{i}/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_OPT_ENERGY_RUN:
    input:      '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/input',
                '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/gwfn.data',
                '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/parameters.casl'
    output:     '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule VMC_OPT_ENERGY_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/input'
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        with open(output[0], 'w') as f:
            f.write(open('../vmc_opt_energy.tmpl').read().format(neu=neu, ned=ned, molecule=wildcards.molecule, backflow='F'))

rule VMC_OPT_ENERGY_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/10000/out'
    output:     '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/parameters.casl'
    run:
        shell('ln -rs "$(dirname "{input}")/parameters.9.casl" "{output}"')
        # workaround in multireference case
        shell('[[ -e "$(dirname "{input}")/correlation.out.9" ]] && ln -rs "$(dirname "{input}")/correlation.out.9" "$(dirname "{output}")/correlation.data"; exit 0')
        # workaround in pseudopotential
        if wildcards.basis.endswith('_PP'):
            for symbol in get_atomic_symbols(wildcards.molecule):
                symbol = symbol.lower()
                shell('cd "$(dirname "{output}")" && ln -s ../../../../../../../../ppotential/DiracFock_AREP/{symbol}_pp.data')


rule VMC_OPT_ENERGY_GWFN:
    input:      '{path}/gwfn.data'
    output:     '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/1000000_9/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_OPT_RUN:
    input:      '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/input',
                '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/gwfn.data',
                '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/parameters.casl',
    output:     '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule VMC_OPT_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/input'
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        with open(output[0], 'w') as f:
            f.write(open('../opt_plan/{}.tmpl'.format(wildcards.jastrow_opt_method)).read().format(
                neu=neu, ned=ned, nconfig=VMC_NCONFIG, molecule=wildcards.molecule, backflow='F'
            ))

rule VMC_OPT_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/parameters.casl'
    run:
        with open(output[0], 'w') as f:
            f.write(open('../casl/{}.tmpl'.format(wildcards.jastrow_rank)).read())
        # workaround in multireference case
        source_path = os.path.join(wildcards.method, wildcards.basis, wildcards.molecule, 'correlation.data')
        target_path = os.path.join(os.path.dirname(output[0]), 'correlation.data')
        shell('[[ -e "{source_path}" ]] && ln -s ../../../../correlation.data "{target_path}"; exit 0')
        # workaround in pseudopotential
        if wildcards.basis.endswith('_PP'):
            for symbol in get_atomic_symbols(wildcards.molecule):
                symbol = symbol.lower()
                shell('cd "$(dirname "{output}")" && ln -s ../../../../../../../../ppotential/DiracFock_AREP/{symbol}_pp.data')


rule VMC_OPT_GWFN:
    input:      '{path}/gwfn.data'
    output:     '{path}/VMC_OPT/{jastrow_opt_method}/{jastrow_rank}/{nconfig}/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_RUN:
    input:      '{path}/VMC/10000000/input'
    output:     '{path}/VMC/10000000/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule VMC_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC/10000000/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC/10000000/input'
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        with open(output[0], 'w') as f:
            f.write(open('../vmc.tmpl').read().format(neu=neu, ned=ned, molecule=wildcards.molecule))
        # workaround in multireference case
        source_path = os.path.join(wildcards.method, wildcards.basis, wildcards.molecule, 'correlation.data')
        target_path = os.path.join(os.path.dirname(output[0]), 'correlation.data')
        shell('[[ -e "{source_path}" ]] && ln -s ../../correlation.data "{target_path}"; exit 0')
        # workaround in pseudopotential
        if wildcards.basis.endswith('_PP'):
            for symbol in get_atomic_symbols(wildcards.molecule):
                symbol = symbol.lower()
                shell('cd "$(dirname "{output}")" && ln -s ../../../../../../ppotential/DiracFock_AREP/{symbol}_pp.data')

rule VMC_GWFN:
    input:      '{path}/gwfn.data'
    output:     '{path}/VMC/10000000/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_DMC_BF_RUN:
    input:      '{path}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/input',
                '{path}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/gwfn.data',
                '{path}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/correlation.data',
                '{path}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/parameters.casl',
    output:     '{path}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule DMC_STATS_BF_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_2/gwfn.data',
                '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_1/out',
                '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_2/config.in',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_2/input'
    params:
        dt_relative_step = 2.0,
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        stderr, _ = dmc_stderr(wildcards.method, wildcards.basis, wildcards.molecule, 'VMC_DMC_BF', wildcards.jastrow_opt_method, wildcards.jastrow_rank + '__' + wildcards.backflow_rank, 'tmax_2_1024_1')
        dtdmc = 1.0/(get_max_Z(wildcards.molecule)**2 * 3.0 * params.dt_relative_step)
        if STD_ERR > stderr:
            nstep = 1
        else:
            nstep = ((stderr/STD_ERR)**2 - 1) * 50000
            nstep = max(10000, int(round(nstep, -4)))
        if wildcards.basis.endswith('_PP'):
            tmove = 'T'
        else:
            tmove = 'F'
        with open(output[0], 'w') as f:
            f.write(open('../dmc_stats.tmpl').read().format(
                neu=neu, ned=ned, nconfig=wildcards.nconfig, dtdmc=dtdmc, molecule=wildcards.molecule, nstep=nstep, nblock=nstep // 1000,
                tmove=tmove, backflow='T'
            ))

rule DMC_STATS_BF_CONFIG:
    input:      '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_1/out',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_2/config.in'
    shell:      'cp "$(dirname "{input}")"/config.out "{output}"'

rule VMC_DMC_BF_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_1/gwfn.data',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_1/input'
    params:
        dt_relative_step = 2.0,
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        dtdmc = 1.0/(get_max_Z(wildcards.molecule)**2 * 3.0 * params.dt_relative_step)
        nstep = 50000
        if wildcards.basis.endswith('_PP'):
            tmove = 'T'
        else:
            tmove = 'F'
        with open(output[0], 'w') as f:
            f.write(open('../vmc_dmc.tmpl').read().format(
                neu=neu, ned=ned, nconfig=wildcards.nconfig, dtdmc=dtdmc, molecule=wildcards.molecule, nstep=nstep, nblock=nstep // 1000,
                tmove=tmove, backflow='T'
            ))

rule VMC_DMC_BF_DATA_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/10000/out',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/correlation.data'
    shell:      'ln -rs "$(dirname "{input}")/correlation.out.9" "{output}"'

rule VMC_DMC_BF_CASL_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/10000/out',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/parameters.casl'
    shell:      'ln -rs "$(dirname "{input}")/parameters.9.casl" "{output}"'

rule VMC_DMC_BF_GWFN:
    input:      '{method}/{basis}/{molecule}/gwfn.data',
    output:     '{method}/{basis}/{molecule}/VMC_DMC_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/tmax_2_{nconfig}_{i}/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_OPT_BF_ENERGY_RUN:
    input:      '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/input',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/gwfn.data',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/correlation.data',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/parameters.casl'
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule VMC_OPT_BF_ENERGY_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/input'
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        with open(output[0], 'w') as f:
            f.write(open('../vmc_opt_energy.tmpl').read().format(neu=neu, ned=ned, molecule=wildcards.molecule, backflow='T'))

rule VMC_OPT_BF_DATA_ENERGY_JASTROW:
    input:      '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/10000/out'
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/correlation.data'
    shell:      'ln -rs "$(dirname "{input}")/correlation.out.9" "{output}"'

rule VMC_OPT_BF_CASL_ENERGY_JASTROW:
    input:      '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/10000/out'
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/parameters.casl'
    shell:      'ln -rs "$(dirname "{input}")/parameters.9.casl" "{output}"'

rule VMC_OPT_BF_ENERGY_GWFN:
    input:      '{path}/gwfn.data'
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/1000000_9/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'

####################################################################################################################

rule VMC_OPT_BF_CASL_RUN:
    input:      '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/input',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/gwfn.data',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/correlation.data',
                '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/parameters.casl',
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/out'
    shell:      'cd "$(dirname "{output}")" && runqmc'

rule VMC_OPT_BF_INPUT:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/input'
    run:
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        with open(output[0], 'w') as f:
            f.write(open('../opt_plan/{}.tmpl'.format(wildcards.jastrow_opt_method)).read().format(
                neu=neu, ned=ned, nconfig=VMC_NCONFIG, molecule=wildcards.molecule, backflow='T'
            ))

rule VMC_OPT_BF_DATA_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/correlation.data'
    run:
        MU_SET = """ START SET {nset}
 Number of atoms in set
   {number_of_atoms}
 Labels of the atoms in this set
   {atom_labels}
 Type of e-N cusp conditions (0->PP/cuspless AE; 1->AE with cusp)
   1
 Expansion order
   {mu_term}
 Spin dep (0->u=d; 1->u/=d)
   {spin_dep}
 Cutoff (a.u.)     ;  Optimizable (0=NO; 1=YES)
   5.0                               1
 Parameter values  ;  Optimizable (0=NO; 1=YES)
 END SET {nset}
"""
        PHI_SET = """ START SET {nset}
 Number of atoms in set
   {number_of_atoms}
 Labels of the atoms in this set
   {atom_labels}
 Type of e-N cusp conditions (0=PP; 1=AE)
   1
 Irrotational Phi term (0=NO; 1=YES)
   0
 Electron-nucleus expansion order N_eN
   {phi_term_eN}
 Electron-electron expansion order N_ee
   {phi_term_ee}
 Spin dep (0->uu=dd=ud; 1->uu=dd/=ud; 2->uu/=dd/=ud)
   1
 Cutoff (a.u.)     ;  Optimizable (0=NO; 1=YES)
   5.0                               1
 Parameter values  ;  Optimizable (0=NO; 1=YES)
 END SET {nset}
"""
        jastrow = wildcards.jastrow_rank.split('_')
        backflow = wildcards.backflow_rank.split('_')
        mu_sets = ''
        phi_sets = ''
        neu, ned = get_up_down(wildcards.method, wildcards.basis, wildcards.molecule)
        for nset, (_, labels) in enumerate(get_lebel_set(wildcards.molecule).items()):
            mu_sets += MU_SET.format(
                number_of_atoms=len(labels),
                spin_dep=0 if neu == ned else 1,
                atom_labels=' '.join(map(str, labels)),
                mu_term=backflow[1],
                nset=nset + 1
            )
            if backflow[2] != '00':
                phi_sets += PHI_SET.format(
                    number_of_atoms=len(labels),
                    atom_labels=' '.join(map(str, labels)),
                    phi_term_eN=backflow[2][0], phi_term_ee=backflow[2][1],
                    nset=nset + 1
                )
        ae_cutoffs = get_ae_cutoffs(wildcards.molecule)
        template = '../backflow_eta_mu.tmpl' if backflow[2] == '00' else '../backflow_eta_mu_phi.tmpl'
        with open(output[0], 'w') as f:
            f.write(open(template).read().format(
                eta_term=backflow[0],
                number_of_mu_sets=nset + 1,
                number_of_phi_sets=nset + 1,
                mu_sets=mu_sets,
                phi_sets=phi_sets,
                ae_cutoffs=ae_cutoffs
            ))
        source_path = os.path.join(wildcards.method, wildcards.basis, wildcards.molecule, 'correlation.data')
        shell('[[ -e "{source_path}" ]] && cat "{source_path}" >> "{output}"; exit 0')


rule VMC_OPT_BF_CASL_JASTROW:
    input:      '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/gwfn.data'
    output:     '{method}/{basis}/{molecule}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/parameters.casl'
    run:
        jastrow = wildcards.jastrow_rank.split('_')
        with open(output[0], 'w') as f:
            f.write(open('../casl/{}.tmpl'.format(wildcards.jastrow_rank)).read())


rule VMC_OPT_BF_GWFN:
    input:      '{path}/gwfn.data'
    output:     '{path}/VMC_OPT_BF/{jastrow_opt_method}/{jastrow_rank}__{backflow_rank}/{nconfig}/gwfn.data'
    shell:      'mkdir -p "$(dirname "{output}")" && ln -rs "{input}" "{output}"'
