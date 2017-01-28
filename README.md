Linux From Scratch pour la construction d'une base en 2 étapes ou pass vont vous permettre de construire un système de base avec systemD et le gestionnaire de Crux. 

Si vous le désirez, vous pouvez utiliser d'autres gestionnaires. 

Rappel : Avant l'arrivée de cards, NuTyX utilisait pkg-get et prt-get de CRUX linux.

Première étape : PASS 1 en ROOT

1. Création de la variable de configuration LFS:
export LFS=/mnt/lfs

2. Création des dossiers:
mkdir -vp $LFS/{sources,tools}

3. Ajout des liens necessaires:
ln -sv $LFS/tools /
ln -sv $LFS/sources /

4. Création de l'utilisateur lfs:
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
passwd lfs

Vous entrez le mot de passe de votre choix, ce n'est pas indispensable si vous entrez ds le compte lfs depuis root.

5. Changement de propriètaire et de mode des dossiers:

chown -v lfs $LFS/{tools,sources}
chmod -v a+wt $LFS/sources
chown -v lfs $LFS

Il est temps de passer à la 2ième partie et donc de se connecter en utilisateur lfs:
 
su - lfs

 A partir de maintenant vous tapez toutes les commandes en compte lfs

1. Ajuster l'envitonnement de travail:

le fichier ~/.bash_profile:
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

et le fichier ~/.bashrc:
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TARGET=$(uname -m)-lfs-linux-gnu
PATH=/home/lfs/bin:/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TARGET PATH
EOF

Et on charge le nouvel environnement:
source ~/.bash_profile

Et pour finir on récupère la dernière version du git:
git clone git://github.com/fanch/makelfs-systemd2.git makelfs


Le clonage commence:
Cloning into makelfs

Une fois terminée, un nouveau dossier a été créé: makelfs. 
On y entre et on lance le premier script:

cd makelfs
sh runmefirst

Le script va effectuer toute une série de vérifications et si aucune erreur ne s'est produite, le téléchargement des sources commence automatiquement. Une fois le téléchargement terminé, il suffit de suivre les instructions.

Si tout s'est bien passé, vous devriez avoir le message:
====> Successfull configured

Si vous lisez ce message, faites:

cd /home/lfs/makelfs/CHROOT
pass

Admirez le travail ...

Et voilà, vous êtes prêt pour lancer la première passe pour la construction de votre future NuTyX:
cd /home/lfs/makelfs/CHROOT
pass

Et admirez le travail

La passe 1 se termine quand vous voyez le texte ci-dessous apparaître:
mkdir: created directory '/mnt/lfs/var/lib/pkg/DB'
=======> Building '/home/lfs/makelfs/CHROOT/cards/Pkgfile' succeeded.

Notez que vous pouvez suivre l'évolution et contrôler la bonne conduite de chaque paquet construit en consultant le dossier /home/lfs/logs/CHROOT/ . En effet à chaque paquet construit correspond un log.


On verra dans un prochain article comment entrer dans la chroot et y construire une NuTyX depuis scratch en utilisant une deuxième fois le même script: pass.

Deuxième étape : PASS 2 en ROOT

Construction de la base NuTyX avec Linux From Scratch et cards (pass 2)
C'est le moment de construire votre NuTyX. Une seule condition: Avoir terminé avec succès la Construction de la CHROOT (pass 1)
 L'auteur n'est pas responsable pour les pertes de données ou autre qui pourrait engendrer une mauvaise manipulation. Cet article s'adresse à un public averti.

Toutes les opérations vont devoir se faire en compte root. Il est donc INDISPENSABLE d'être très vigilant sinon vous pouvez "casser" votre distribution actuelle.
La variable LFS pointe dans notre exemple sur /mnt/lfs. A vous d'ajuster si vous avez choisi un autre emplacement.

 Veuillez notez que la pass 2 peut s'avérez beaucoup plus "aventureuse" dans le sens qu'il est tout à fait possible qu'un paquet ne se compile pas du premier coup. Il est important de le signaler dans la rubrique Aide->Soupsons de bugs ou sur le canal irc

Pour éviter tout risque de dispersion et pour faciliter la lecture, l'article sera divisé en deux parties: 

La première reprend chaque action numérotée une à une et la deuxième donne une explication de chaque action.

Vous devrez effectuer 22 actions  :

Donc encore une fois toutes les opérations se font dans le compte root.

On commence donc par passer en root:

1. On passe en chroot
su -

2. On défini la variable LFS
export LFS=/mnt/lfs

3. On vérifie la variable LFS
echo $LFS
/mnt/lfs
 AVANT D'ALLER PLUS LOIN ASSUREZ-VOUS QUE LA VARIABLE LFS SOIT CORRECTEMENT DEFINIE. SI CELLE-CI EST INCORRECTE, VOUS ALLEZ CASSER VOTRE DISTRIBUTION

Si le résultat est correcte:
chown -R root:root $LFS

4. On entre ds le dossier de la recette de nutyx
cd /home/lfs/makelfs/base/nutyx

5. On crééer un fichier de configuration temporaire
echo "PKGMK_PACKAGE_DIR=/home/lfs/makelfs/base/nutyx" > pkgmk.conf

6. On compile le premier paquet de la NuTyX
/tools/bin/pkgmk -cf pkgmk.conf -d

7. On installe le premier paquet dans la NuTyX
/tools/bin/pkgadd -r $LFS nutyx#*

8. On vérifie sa présence
/tools/bin/pkginfo -r $LFS -i
nutyx 7.10-1


9. Et pour finir son installation, on efface le fichier 
rm pkgmk.conf

10. On monte les différents dossiers
mount -v --bind  /dev /$LFS/dev
mount -vt devpts devpts $LFS/dev/pts
mount -vt tmpfs shm $LFS/dev/shm
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount --bind /sources  $LFS/sources

11. On copie resolv.conf
cp -v /etc/resolv.conf $LFS/etc

12. On créer les dossiers de travail
mkdir -pv $LFS/root/{logs,makelfs} 

13. On monte le projet de construction makelfs
mount --bind -v /home/lfs/makelfs $LFS/root/makelfs


14. On vérifie que tous les dossiers soient correctement monté
mount|grep $LFS
-------------résultat-------------
/dev on /mnt/lfs/dev type none (rw,bind)
devpts on /mnt/lfs/dev/pts type devpts (rw)
proc on /mnt/lfs/proc type proc (rw)
sysfs on /mnt/lfs/sys type sysfs (rw)
shm on /mnt/lfs/dev/shm type tmpfs (rw)
/home/lfs/makelfs on /mnt/lfs/root/makelfs type none (rw,bind)
/home/lfs/base on /mnt/lfs/root/base type none (rw,bind)

15. On entre dans la NuTyX
chroot "$LFS" /usr/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' /bin/bash --login +h

16. On redéfinie la variable PATH et lance la compilation des paquets
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin:/root/bin
cd
ln -s makelfs/bin
cd makelfs/base
pass

17. La compilation se termine par le kernel :
/tools/bin/pkgmk: line 99: pkg-get-version: command not found
=======> Building '/srv/NuTyX/release/headers#4.7.2-1.pkg.tar.xz'.
bsdtar -p -o -C /tmp/work/src -xf /sources/linux-4.7.2.tar.xz
...


Construction de la NuTyX (pass 2)

Explications relative à chaque action

1. Il est indispensable d'effectuer toutes les opérations via le compte root.

2. La variable LFS est utilisé tout au long de l'article, il est indispensable qu'elle soit correctement définie et surtout qu'elle soit identique tout au long des 2 passes. Une solution radicale consiste à la définir une fois pour toute dans le fichier .bash_profile du compte root
echo "export LFS=/mnt/lfs" >> /root/.bash_profile 

3. Vérification de la variable LFS. Si vous l'avez entrée dans le fichier de configuration. Il est nécessaire de le faire :
source  ~/.bash_profile 
et ensuite de la vérifier. Si tout est ok, on change le propriétaire et le groupe du contenu du dossier $LFS

4. On va maintenant compiler le premier paquet qui est nutyx. Pour cela on se rend dans son dossier.

5. Comme il doit être possible de construire une NuTyX sur autre qu'une NuTyX, il faut s'assurer qu'un fichier de configuration existe. On créé donc un fichier temporaire.

6. On compile le premier paquet qui d'ailleurs ne contient aucun code, ce paquet consiste à crééer tous les dossiers et fichiers de configuration de votre NuTyX. Il constitue à la fois la base de travail de votre construction et l'arborescence de votre système. Ce paquet ne devrait jamais être mis à jour par la suite. Mais là encore tout est possible et flexible.
 
7. Maintenant, on installe le premier paquet nutyx. Dans certaine archive, vous pourrez trouver d'ancienne version de contruction appelée aaabasicfs. Elle avait la même fonction et vous proposait une base de cosntruction pour un systemV.

8. On vérifie bien sa présence dans la base de données de celle-ci. 

9. On peut alors supprimer le fichier de configuration temporaire pkgmk.conf.

10. Il s'agit maintenant de monter les quelques dossiers indispensable au bon déroulement des opérations de compilation.

11. Pour que le cas échéant, une recette nécessite de télécharger les sources, on copie le fichier resolv.conf qui définit le routage et la résolution de noms de domaine.

12. Il faut créér quelques dossiers de travail: logs pour pouvoir consulter les logs de compilation de chaque paquet. Make-NuTyX pour pouvoir profiter des outils et nutyx-current pour avoir la liste des recettes à compiler.

13. Comme on travaille dans un environnement chroot, il faut monter les dossiers des projets en utilisant l'option bind.

14. Une dernière vérification sur la présence de tous les dossiers concernés.

15. On peut maintenant entrer dans la CHROOT cad la future NuTyX. Comme il n'y a encore aucun programme au bon endroit, on obtient une erreur lors de la commande chroot et la variable PATH est à redéfinir pour que toutes les commandes binaires soient présentées dans le bon ordre.

16. La variable PATH est réajustée. On se remet dans le dossier personnel (/root). On effectue le seul lien necessaire pour pouvoir profiter du script pass , le même script qui a été utilisé pour la première pass. On se met dans le dossier des recettes NuTyX version courante. Et on lance la compilation des paquets dans le bonne ordre.

17. La compilation se termine par le noyau linux ou kernel.

Ce qu'il faut savoir:

1. Si vous avez une erreur lors de la compilation d'une recette, ce n'est pas grave, lorsque vous relancez la commande pass, le script reprend le travail là où il s'est arrêté. Afin de faire profiter un maximum de lecteurs, merci de nous informer du problème soit sur le canal irc soit sur le site via Aide->Soupçon de bug.

2. Si vous pensez que le bug est corrigé, n'oubliez pas de mettre à jour votre dépot git via la commande
git pull dans les dossiers makelfs-systemd.

3. Vous pouvez effectuez la pass2 en plusieurs étapes. Si vous êtes sorti de la chroot, vous DEVEZ alors vous assurez de retaper les commandes 14 et 15 (sans faire le lien ln -s makelfs/bin). Si vous avez arrêtez la machine, assurez-vous de tapez les commandes: 10 et 11 en plus des commandes 13 et 16, toujours sans faire le lien ln -s makelfs/bin.

Ce tutoriel n'a qu'un seul but : Constuire une LFS/NuTyX systemd en collant au plus prés de LFS avec cards. Encore une fois, vous pourrez apprécier la flexibilité de l'ensemble et pour les plus aventureux, vous pourrez même proposer une construction avec un autre gestionnaire.

Nota: Vous pouvez constuire un systemV dans les mêmes conditions ou vous rendre sur le site de NuTyX et procéder à votre propre construction en suivant le Tutoriel situé dans l'onglet documentation.

Encore Merci à Thierry Nuttens et Bonne construction

 

