%% calculates the surface temperature of the Earth using radiation, ground
%heat flux and sensible heat flux

 %parameters
result_water = [];
result_surface = [];
result_subsurface = [];
result_evaporation = [];
result_saturation = [];
result_sens = [];
result_lout = [];
result_latent = [];
result_T1 = [];
result_T2 = [];
result_cond = [];

for bucket_depth = 0.1:0.4:0.9;
%for bucket_depth = 0.1:0.2:1.1;
    water_level = 0.05;
    c_h = 2.2e6; % heat capacity of rock [J/m3K]
    K = 3; % thermal conductivity of rock [W/m K]
    d_1 = 0.3*bucket_depth; % thickness of surface grid cell [m]
    d_2 = 0.7*bucket_depth; %thickness of second grid cell [m]
    albedo = 0.2; %albedo of surface
    %bucket_depth = 0.5; % maximum depth of baucket for storage of water [m]
    %drainage_constant = exp(3*bucket_depth); %mm/day subsurface runoff for saturation = 1
    drainage_constant = 1.5;
    
    startTime = 0; % [days]
    endTime = 2.*365;
    timestep = 3/24 ./100; %?
    outputTimestep = 3/24; %every 3h
    %1 gives more values, so 3 gives 3h accumulated value
    %constants
    sigma = 5.67e-8; %Stefan-Boltzmann constant [J/m2 K4]
    daySec = 24 .* 60 .*60; %number of seconds in one day [sec]

    %initialization for t = 0
    t = startTime; %time [sec]
    T_1 = 0; %initial surface grid cell temperature [degree C];
    T_2 = 0; %initial temperature of second grid cell [degree C];
    %water_level = bucket_depth ./ 2; %half full bucket
    E_1 = c_h .* d_1 .* T_1; % initial energy of the block [J/m2]
    E_2 = c_h .* d_2 .* T_2; % initial energy of the block [J/m2]

    %store values
    T_1_store = T_1;  %surface temperature stored here!
    T_2_store = T_2;
    sens_store = 0;
    lout_store = 0;
    latent_store = 0;
    cond_store = 0;
    water_level_store = water_level;
    surface_runoff_store = 0;
    subsurface_runoff_store = 0;
    result_evaporation_store= 0;
    t_store = t;
    saturation_store=0;

    %load('forcing_SEB_Suossjavri.mat')  %Change between Finse and Suossjavri/Finnmark by commenting out the forcing file
    load('forcing_SEB_Finse.mat')

    %main program
    count=0;
   rain_store = 0; 
     
    for t = startTime:timestep:endTime
        %water balance - rainfall and subsurface outflow, only if ground is not
        %frozen
         water_in_rainfall = interpolate_in_time(t, rainfall) ./1000 ./ daySec;  %from forcing data, convert mm/day to m/sec
        if T_1>=0 && T_2>= 0  %only if the ground is unfrozen
           %water_in_rainfall = interpolate_in_time(t, rainfall) ./1000 ./ daySec;  %from forcing data, convert mm/day to m/sec
            saturation =  water_level ./ bucket_depth;
            water_out_subsurface_runoff = drainage_constant ./1000 ./ daySec .* saturation;
        else
            water_out_subsurface_runoff = 0;
        end
        
        %incoming and ougoing shortwave (solar) radiation
        S_in = interpolate_in_time(t, Sin);  %from forcing data
        S_out = albedo .* S_in;

        %incoming and ougoing (thermal) radiation
        L_in = interpolate_in_time(t, Lin);  %from forcing data
        L_out = sigma .* (T_1+273.15).^4; %from Stefan-Botzman law [J/ sec m2]

        %ground heat flux
        F_cond = -K.*(T_1 - T_2)./( (d_1+d_2)./2 ); %Fourier's Law of heat conduction

        %sensible heat flux
        T_air = interpolate_in_time(t, Tair);  %from forcing data
        wind_speed = interpolate_in_time(t, windspeed);  %from forcing data
        F_sensibleHeat = Q_h(T_air, T_1, wind_speed);

        %latent heat flux/evapostranspiration
        absolute_humidity = interpolate_in_time(t, q);  %from forcing data
        [F_latentHeat, water_out_evapotranspiration] = Q_eq(T_1, absolute_humidity, wind_speed, saturation);

        %time integration - advance to next timestep

        %surface energy balance 
        E_1 = E_1 + timestep .* daySec .* (S_in - S_out + L_in - L_out - F_sensibleHeat - F_latentHeat + F_cond); %  SURFACE ENERGY BALANCE EQUATION!!!!
        E_2 = E_2 + timestep .* daySec .* (-F_cond); 
        T_1 = E_1 ./ (c_h .* d_1); %convert emegy contemt to temeprature, using the heat capacity
        T_2 = E_2 ./ (c_h .* d_2);

        %water balance
        if T_1>=0 && T_2>= 0  %only if the ground is unfrozen
            water_level = water_level + timestep .* daySec .* (water_in_rainfall - water_out_evapotranspiration - water_out_subsurface_runoff);  % WATER BALANCE EQUATION
            surface_run_off = max(0, water_level - bucket_depth); %if water level is higher than the bucket
            water_level = min(water_level, bucket_depth); %remove water when bucket tops over
        else
            surface_run_off = 0;
        end

        %store values
        if mod(count,outputTimestep./timestep)==0
            T_1_store = [T_1_store ; T_1];
            T_2_store = [T_2_store ; T_2];
            lout_store = [lout_store; L_out];
            sens_store = [sens_store; F_sensibleHeat];
            latent_store = [latent_store; F_latentHeat];
            cond_store = [cond_store; F_cond];
            water_level_store = [water_level_store; water_level];
            surface_runoff_store = [surface_runoff_store ; surface_run_off ./timestep .*1000];  %in mm/day!!!!
            subsurface_runoff_store = [subsurface_runoff_store ; water_out_subsurface_runoff .* daySec .*1000]; % in mm/day!!!!
            t_store = [t_store; t];
            result_evaporation_store=[result_evaporation_store;water_out_evapotranspiration];
            rain_store = [rain_store; water_in_rainfall];
            saturation_store = [saturation_store; saturation];
        end
        count=count+1;
        
    end
        result_water=[result_water water_level_store];
        result_surface = [result_surface surface_runoff_store];
        result_subsurface = [result_subsurface subsurface_runoff_store];
        result_evaporation = [result_evaporation result_evaporation_store];
        result_saturation=[result_saturation saturation_store];
        result_sens = [result_sens sens_store];
        result_latent = [result_latent latent_store];
        result_T1 = [result_T1 T_1_store];
        result_T2 = [result_T2 T_2_store];
        result_cond = [result_cond cond_store];
        result_lout = [result_lout lout_store];
end

figurepath = 'C:\Users\Eirik N\Documents\UiO\GEO4432\LaTex\figures';

%% Water level
P1 = movmean(rain_store*1000*daySec,8,'Endpoints','discard');

figure
hold all, grid on
plot(result_water(:,1), 'linewidth',1); plot(result_water(:,2), 'linewidth',1); plot(result_water(:,3), 'linewidth',1);
%plot(result_water(:,4), 'linewidth',1); plot(result_water(:,5), 'linewidth',1);
res = rescale(P1,0,0.9);
p1=plot(res,'color','black');p1.Color(4)=0.25;
title('Water Level with varying bucket depth')
xlabel('Time [3h]'), ylabel('Water level [m]')
lgd = legend('0.1','0.5','0.9','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/bucket_depth_fixed.png']);
%% Surface Runoff
figure, hold all, grid on
R = movmean(result_surface,8,'Endpoints','discard');
res = rescale(P1,0,70);
p1=plot(R(:,1),'-','LineWidth',1); p2 = plot(R(:,2),'-', 'LineWidth',1); 
p3=plot(R(:,3),'-','LineWidth',1); %p4 = plot(R(:,4),'-', 'LineWidth',1);
%p5 = plot(R(:,5),'-','LineWidth',1);
p=plot(res,'color','black');p.Color(4)=0.25;
title('Surface Runoff with varying bucket depth')
xlabel('Time [3h]'), ylabel('Surface Runoff [mm/day]')
lgd = legend('0.1','0.5','0.9','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/runoff.png']);
%% Subsurface runoff
figure
hold all, grid on
plot(result_subsurface(:,1)), plot(result_subsurface(:,2)), plot(result_subsurface(:,3))
%plot(result_subsurface(:,4)), plot(result_subsurface(:,5))
title('Subsurface Runoff with varying bucket depth')
xlabel('Time'), ylabel('Surface Runoff [mm/day]')
lgd = legend('0.1','0.5','0.9','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/subsurface.png']);

%% Precipitation and air temperature 
%moving mean of precip
P1 = movmean(rain_store*1000*daySec,8,'Endpoints','discard');
fig = figure;
left_color=[1 0 0]; right_color=[0 0 0];
set(fig,'defaultAxesColorOrder',[left_color; right_color]);

hold all, grid on
xlim([0,6000])
yyaxis left
ylabel('Temperature [{\circ}C]')
plot(Tair,'linewidth',0.3) 
yyaxis right
ylabel('Precipitation [mm/day]')
plot(P1,'linewidth',0.8)
legend("Surface temp.", "Precip.")
xlabel('Time [3h]')
title("Data, Finse")
saveas(gcf,[figurepath,'/precip.png']);

%% Evaporation
%startdate = datenum('2014-10-02');
%enddate = datenum('2019-03-16');
%xData = linspace(startdate,enddate,4);
P1 = movmean(rain_store*1000*daySec,8,'Endpoints','discard');
figure, hold all, grid on
res = rescale(P1,0,20);
E=result_evaporation*1000*daySec;
p1=plot(E(:,1),'-','LineWidth',1); p2 = plot(E(:,2),'-', 'LineWidth',1); 
p3=plot(E(:,3),'-','LineWidth',1); %p4 = plot(E(:,4),'-', 'LineWidth',1);
%p5 = plot(E(:,5),'-','LineWidth',1);
p=plot(res,'color','black');p.Color(4)=0.25;
title('Evaporation with varying bucket depth')
xlabel('Time [3h]'), ylabel('Evaporation [mm/day]')
%datetick('x','mmm','keepticks')
lgd = legend('0.1','0.5','0.9','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/evaporation.png']);

%% Sensible heat flux
figure,hold on, grid on
p1=plot(result_sens(:,1)), p2=plot(result_sens(:,2));p3=plot(result_sens(:,3));
%p4=plot(result_sens(:,4));p5=plot(result_sens(:,5));
p1.Color(4)=0.95; p2.Color(4)=0.95; p3.Color(4)=0.25; %p5.Color(4)=0.65; p5.Color(4)=0.65;
title('Sensible Heat Flux'); xlabel('Time'); ylabel('W(m^2)');
lgd = legend('0.1','0.5','0.9','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/sensible_heat.png']);
%% Latent heat flux
figure,hold on, grid on
p1=plot(result_latent(:,1)), p2=plot(result_latent(:,2));p3=plot(result_latent(:,3));
%p4=plot(result_latent(:,4));p5=plot(result_latent(:,5));
title('Latent Heat Flux'); xlabel('Time'); ylabel('W(m^2)');
lgd = legend('0.1','0.5','1.0','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/latent_heat.png']);
%% Conductional heat flux
figure,hold on, grid on
p1=plot(result_cond(:,1)), p2=plot(result_cond(:,2));p3=plot(result_cond(:,3));
%p4=plot(result_cond(:,4));p5=plot(result_cond(:,5));
title('Conductional Heat Flux');xlabel('Time'); ylabel('W(m^2)');
lgd = legend('0.1','0.5','1.0','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/conduction.png']);
%% Temperatures
figure,hold on, grid on
p1=plot(result_T1(:,1)), p2=plot(result_T1(:,2));p3=plot(result_T1(:,3));
%p4=plot(result_T1(:,4));p5=plot(result_T1(:,5));
p3.Color(4)=0.15
title('Temperature Surface Layer'); xlabel('Time'); ylabel('{\circ}C');
lgd = legend('0.1','0.5','1.0','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/t_surface.png']);

figure,hold on, grid on
p1=plot(result_T2(:,1)), p2=plot(result_T2(:,2));p3=plot(result_T2(:,3));
%p4=plot(result_T2(:,4));p5=plot(result_T2(:,5));
title('Temperature 2nd. Layer'); xlabel('Time'); ylabel('{\circ}C');
lgd = legend('0.1','0.5','1.0','Precip','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/t_ground.png']);

%% Longwave outgoing radiation
figure,hold on, grid on
p1=plot(result_lout(:,1)), p2=plot(result_lout(:,2));p3=plot(result_lout(:,3));
%p4=plot(result_lout(:,4));p5=plot(result_lout(:,5));
ylim([200 500])
title('Longwave Outgoing Radiation'); xlabel('Time'); ylabel('W/m^2');
lgd = legend('0.1','0.5','1.0','Location','northwest');
title(lgd,'Bucket Depth [m]')
saveas(gcf,[figurepath,'/longwave.png']);