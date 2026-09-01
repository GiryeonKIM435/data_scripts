function run_fit_jeffreys_visco(opts)
%RUN_FIT_JEFFREYS_VISCO Jeffreys creep identification (public entry)
if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
run_fit_burgers_visco(opts);
end
