clear; close all; clc;
global H T

% A = [1  0 0
%     .5 1 0
%     0 0.3  1
%     .3 .5  .2
%     .2  .9 3.7
%     0 .6 -.5];
A = [1  0.7
    .5 1 
    0.3 0.3 
    0.5 0.4 ];
true_model = 14;

[m, n] = size(A);
T = 200;

true_restr = decode_restr(true_model, n, m-1) == 0;
true_restr  = [true_restr(1:n, :); ones(1, n) == 1; ...
        true_restr(end, :)];
%isConstrained = false(size(A)); isConstrained(1, 2) = true;
%isConstrained(1:2, 3) = true;
%isConstrained(3, 2) = true;
%% Generate data
        A_true = A .* (~true_restr) ;
        A0 = A_true(1:n, :); A1 = A_true((n+1):m, :);

        resid = randn(T, n);
        Y(1, :) = resid(1, :) / A0;
        for i = 2:T
            Y(i, :) = (-Y(i - 1, :) * A1 + resid(i, :))/ A0;
        end

        Z = Y(1:(end - 1), :); Y = Y(2:end, :);

        X = [Y Z];
        H = chol(cov(X));

%% MH MCMC
which_val = 1e-17:1e-16:9e-15;
num_tries = 10;

log_ml = zeros(length(which_val), num_tries, 15); log_ml2 = ...
    ones(length(which_val),num_tries, 15);
var_ml = zeros(length(which_val), num_tries, 15);
mcmc_A = cell(1, length(which_val)); mean_A = cell(1, length(which_val));
Prob = zeros(length(which_val), num_tries, 15); Prob2 = zeros(length(which_val), num_tries, 15);


s = 1;
num_tries = 10;
for k = which_val
    prior_vars = [k, 200];
    for t = 1:num_tries
        mcmc_A{s} = cell(1, 15); mean_A{s} = cell(1, 15);
        A_true = A .* (~true_restr) ;
        A0 = A_true(1:n, :); A1 = A_true((n+1):m, :);

        resid = randn(T, n);
        Y(1, :) = resid(1, :) / A0;
        for i = 2:T
            Y(i, :) = (-Y(i - 1, :) * A1 + resid(i, :))/ A0;
        end

        Z = Y(1:(end - 1), :); Y = Y(2:end, :);

        X = [Y Z];
        H = chol(cov(X));

        for model = [14, 15]
            fprintf(['c =  ', num2str(k), '; Try ',...
                num2str(t), '; Model ', num2str(model), '\n'])
            
            isConstrained = decode_restr(model, n, m-1) == 0;
            isConstrained = [isConstrained(1:n, :); ones(1, n) == 1; ...
                isConstrained(end, :)];
            [A0, isIdentified] = tsls(X, isConstrained);
            if any(~isIdentified)
                error('The structural model is not identified')
            end

            which_sample = ones(m, n) == 1;
            fprintf('MCMCMH procedure starts \n')
            tic
            [Ahat, Accept_ratio, acceptanceRate] = mcmc_bad2(isConstrained, A0, which_sample, 500, 1e3);
            toc

            mcmc_A{s}{model} = mcmc_summary(Ahat', 500, 1, 0);
            mean_A{s}{model} = reshape(mcmc_A{s}{model}.descr_stats(:, 1), m, n);
            fprintf('Chib procedure starts \n')
            tic;
            [lml, var_ml(s, t, model)] = chib_marginal_ll(mean_A{s}{model}, ...
                Ahat, prior_vars, Y, Z, isConstrained, 0, 500, 1e3);
            toc
            lml(isnan(lml)) = -Inf;
            log_ml(s, t, model) = lml;
            log_ml2(s, t, model) =  newton_raftery_marginal_ll(Ahat, n, m);
        end
        Prob(s, t, [14, 15]) = ...
            exp(log_ml(s, t, [14, 15]))./sum(exp(log_ml(s, t, [14, 15])));
        Prob2(s, t, :) = exp(log_ml2(s, t, :))./sum(exp(log_ml2(s, t, :)));
    end
    s = s + 1;
end

%%

disp('Marginal Likelihoods (Chib method):')
disp(log_ml)

 
disp('Marginal Likelihoods (Newton-Raftery method):')
disp(log_ml2)
 

  disp('Posterior probabilities (Chib method):')
 disp(mean(Prob, 1))
 
   disp('Posterior probabilities (Newton-Raftery  method):')
 disp(mean(Prob2, 1))
 
 P14 = Prob(:, :, 14);
 P15 = Prob(:, :, 15);
 
  mP14 = mean(P14, 2);
  mP15 = mean(P15, 2);
 