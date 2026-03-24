#!/bin/bash
rm -f /home/dmdba/*.buf
DMPATH=/dm/bin
conn_s=sysdba/Dameng123@localhost:5236
total=100
a1=4
a2=14
a3=8
a4=18
a5=8
a6=20
a7=8
a8=10
a9=10


echo   "第1题:数据库卸载"
if [ -d "/home/dmdba/dmdbms/jar" ] 
	then
		echo "数据库软件未成功卸载:-4"
      echo  $((a1=a1-4)) >/dev/null
fi

echo   "第2题:重新安装部署数据库"
if [ -d "/dm" ] 
	then
		echo ""
	else 
		echo "安装路径:-2"
                         echo  $((a2=a2-2)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_dbname.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_instance.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_portnum.sql>/dev/null

DBNAME=`head -1 /home/dmdba/a.buf|tr -s "  " |cut -d " " -f 2`
if [ $DBNAME = "DAMENG" ]
	then 
		echo ""
	else 
		echo "数据库名:-1"
                         echo  $((a2=a2-1)) >/dev/null
fi

INS_NAME=`head -1 /home/dmdba/b.buf|tr -s "  " |cut -d " " -f 2`
if [ $INS_NAME = "PROD" ]
        then
                echo ""
        else
                echo "实例名:-1"
            echo  $((a2=a2-1)) >/dev/null
fi

PORT_NUM=`head -1 /home/dmdba/c.buf|tr -s "  " |cut -d " " -f 2`
if [ $PORT_NUM == 5236 ]
        then
                echo ""
        else
                echo "端口号:-1"
              echo  $((a2=a2-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_charset.sql >/dev/null
CHARSET=`head -1 /home/dmdba/f1.buf|tr -s "  " |cut -d " " -f 2`
if [ $CHARSET == 1 ]
        then
                echo ""
        else
                echo "字符集:-1"
                echo  $((a2=a2-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_recover.sql >/dev/null
RECOVER1=`head -1 /home/dmdba/x.buf|tr -s "  " |cut -d " " -f 2`
if [ $RECOVER1 == 107 ] 
        then
                echo $RECOVER1
                echo ""
        else
						echo $RECOVER1
                echo "原有数据库的数据未恢复:-8"
echo  $((a2=a2-8)) >/dev/null
fi


echo "第3题:表空间及用户规划"

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tbsinitsize.sql >/dev/null
TBSINITSIZE=`head -1 /home/dmdba/i.buf|tr -s "  " |cut -d " " -f 2`
if [ $TBSINITSIZE == 64 ]
        then
                echo ""
        else
                echo "表空间初始大小:-1"
    echo  $((a3=a3-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tbsnext.sql >/dev/null
TBSNEXT=`head -1 /home/dmdba/i1.buf|tr -s "  " |cut -d " " -f 2`
if [ $TBSNEXT == 2 ]
        then
                echo ""
        else
                echo "表空间扩展值:-1"
    echo  $((a3=a3-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tbsmax.sql >/dev/null
TBSMAX=`head -1 /home/dmdba/j.buf|tr -s "  " |cut -d " " -f 2`
if [ $TBSMAX == 5120 ]
        then
                echo ""
        else
                echo "表空间最大值:-2"
    echo  $((a3=a3-2)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_usertest.sql >/dev/null
USERTEST=`head -1 /home/dmdba/k.buf|tr -s "  " |cut -d " " -f 2`
if [ $USERTEST = "DMEXAM" ]
        then
                echo ""
        else
                echo "账户不存在:-1"
       echo  $((a3=a3-1)) >/dev/null
fi


$DMPATH/disql -s $conn_s \`/var/local/sc/rw_userlife.sql >/dev/null
USERLIFE=`head -1 /home/dmdba/nnn.buf|tr -s "  " |cut -d " " -f 2`
if [ $USERLIFE = 120 ]
        then
                echo ""
        else
                echo "密码强制过期设置错误:-1"
       echo  $((a3=a3-1)) >/dev/null
fi


$DMPATH/disql -s $conn_s \`/var/local/sc/rw_usertbs.sql >/dev/null
USERTBS=`head -1 /home/dmdba/l.buf|tr -s "  " |cut -d " " -f 2`
if [ $USERTBS = "TBS" ]
        then
                echo ""
        else
                echo "用户默认的表空间:-1"
       echo  $((a3=a3-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_userprivs1.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_userprivs2.sql >/dev/null
PRIV1=`head -1 /home/dmdba/userprivs1.buf|tr -s "  " |cut -d " " -f 3`
PRIV2=`head -1 /home/dmdba/userprivs2.buf|tr -s "  " |cut -d " " -f 3`

if [ $PRIV1 = "TABLE" ] && [ $PRIV2 = "PROCEDURE" ] 
        then
                echo ""
        else
                echo "DMEXAM用户权限错误:-1"
echo  $((a3=a3-1)) >/dev/null
fi

echo "第4题:表管理及数据导出"
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tabdata1.sql >/dev/null
TABDATA1=`head -1 /home/dmdba/xxx.buf|tr -s "  " |cut -d " " -f 2`
if [ $TABDATA1 == 46 ] 
        then
                echo ""
        else
                echo "部门表未能导入:-4"
echo  $((a4=a4-4)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tabdata2.sql >/dev/null
TABDATA2=`head -1 /home/dmdba/y.buf|tr -s "  " |cut -d " " -f 2`
if [ $TABDATA2 == 856 ]
        then
                echo ""
        else
                echo "员工表未能导入:-4"
echo  $((a4=a4-4)) >/dev/null
fi


$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tab_col.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_data_default.sql >/dev/null
TAB_COL=`head -1 /home/dmdba/tab_col.buf|tr -s "  " |cut -d " " -f 2`
DATA_DEFAULT=`head -1 /home/dmdba/data_default.buf|tr -s "  " |cut -d " " -f 2`
if [ $TAB_COL = "CREATETIME" ]  &&  [ $DATA_DEFAULT = "SYSDATE" ] 
        then
                echo ""
        else
                echo "CREATETIME列添加失败:-2"
echo  $((a4=a4-2)) >/dev/null
fi

if [ -f "/dm/data/TAB_EMP.CSV" ]
then
echo ""
else
echo "TAB_EMP表没有导出:-8"
echo  $((a4=a4-8)) >/dev/null
fi

echo "第5题:创建试图"
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_view_tab1.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_view_content1.sql >/dev/null
VIEW_TAB1=`head -1 /home/dmdba/view_tab1.buf|tr -s "  " |cut -d " " -f 2`
VIEW_CONTENT1=`head -1 /home/dmdba/view_content1.buf|tr -s "  " |cut -d " " -f 2`
if  [ $VIEW_TAB1 = "V_EMPNUM" ] && [ $VIEW_CONTENT1 = "开发部"  ]
        then
                echo ""
        else
                echo "视图V_EMPNUM创建失败:-4"
echo  $((a5=a5-4)) >/dev/null
fi


$DMPATH/disql -s $conn_s \`/var/local/sc/rw_view_tab2.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_view_content2.sql >/dev/null
VIEW_TAB2=`head -1 /home/dmdba/view_tab2.buf|tr -s "  " |cut -d " " -f 2`
VIEW_CONTENT2=`head -1 /home/dmdba/view_content2.buf|tr -s "  " |cut -d " " -f 2`
if  [ $VIEW_TAB2 == 10 ] && [ $VIEW_CONTENT2 = "7237"  ]
        then
                echo ""
        else
                echo "视图V_EMPSAL创建失败-4"
echo  $((a5=a5-4)) >/dev/null
fi


echo "第六题:数据库开发"
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_proc.sql >/dev/null
PROC=`head -1 /home/dmdba/proc.buf|tr -s "  " |cut -d " " -f 2`
if  [ $PROC == 270 ] 
        then
                echo ""
        else
                echo "函数建失败-10"
echo  $((a6=a6-10)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_tab1.sql >/dev/null
TAB1=`head -1 /home/dmdba/tab1.buf|tr -s "  " |cut -d " " -f 2`
if [ $TAB1 =  "T_EVENTLOG" ] 
        then
                echo ""
        else
                echo "记录触发器信息的表不存在:-2"
echo  $((a6=a6-2)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_trigg1.sql >/dev/null
OWNER1=`head -1 /home/dmdba/trigg1.buf|tr -s "  " |cut -d " " -f 2`
NAME1=`head -1 /home/dmdba/trigg1.buf|tr -s "  " |cut -d " " -f 3`
if [ $OWNER1 = "DMEXAM" ] && [ $NAME1 = "TR_EVENTLOG" ] 
        then
                echo ""
        else
                echo "触发器创建失败:-8"
echo  $((a6=a6-8)) >/dev/null
fi

echo "第7题:定时作业"

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_job1.sql >/dev/null
JOBNAME=`head -1 /home/dmdba/job1.buf|tr -s "  " |cut -d " " -f 2`
INTERVAL=`head -1 /home/dmdba/job1.buf|tr -s "  " |cut -d " " -f 3`
STIME=`head -1 /home/dmdba/job1.buf|tr -s "  " |cut -d " " -f 4`
TYPE=`head -1 /home/dmdba/job1.buf|tr -s "  " |cut -d " " -f 5`
if [ $JOBNAME = "FULLBAK" -o $JOBNAME = "fullbak" ] && [  $INTERVAL = 1 ] && [ $STIME = "01:00:00" ] && [ $TYPE = 2 ]
        then 
                echo ""
        else
                echo "FULLBAK不正确:-4"
echo  $((a7=a7-4)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_job2.sql >/dev/null
JOBNAME=`head -1 /home/dmdba/job2.buf|tr -s "  " |cut -d " " -f 2`
INTERVAL=`head -1 /home/dmdba/job2.buf|tr -s "  " |cut -d " " -f 3`
STIME=`head -1 /home/dmdba/job2.buf|tr -s "  " |cut -d " " -f 4`
TYPE=`head -1 /home/dmdba/job2.buf|tr -s "  " |cut -d " " -f 5`
if [ $JOBNAME = "DELARCH" -o $JOBNAME = "delarch" ] && [  $INTERVAL = 0 ] && [ $STIME = "01:00:00" ] && [ $TYPE = 1 ]
        then 
                echo ""
        else
                echo "DELARCH不正确:-4"
echo  $((a7=a7-4)) >/dev/null
fi


echo "第8题：性能优化"

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_index.sql >/dev/null
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_index_count.sql >/dev/null
CHANGE=`head -1 /home/dmdba/index.buf|tr -s "  " |cut -d " " -f 2`
COLUMN=`head -1 /home/dmdba/index_count.buf|tr -s "  " |cut -d " " -f 2`
if  [ $CHANGE = "IX_EMP_EMPNAME" ] &&   [ $COLUMN = "EMPLOYEE_NAME" ]
        then
                echo ""
        else
                echo "索引IX_EMP_EMPNAME未创建:-3"
echo  $((a8=a8-3)) >/dev/null
fi


$DMPATH/disql -s $conn_s \`/var/local/sc/rw_statistic.sql >/dev/null
STATISTIC=`head -1 /home/dmdba/statistic.buf|tr -s "  " |cut -d " " -f 2`
if  [ $STATISTIC = "NULL"  ] 
        then
                echo "未搜集TAB_EMP表的统计信息:-4"
        echo  $((a8=a8-4)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_sqlbuf.sql >/dev/null
SIZE=`head -1 /home/dmdba/sql.buf|tr -s "  " |cut -d " " -f 2`
if  [ $SIZE == 500 ]
        then
                echo ""
        else
                echo "SQL缓冲区大小设置错误:-3"
echo  $((a8=a8-3)) >/dev/null
fi

echo "第9题：数据库安全"
$DMPATH/disql -s $conn_s \`/var/local/sc/rw_arch.sql >/dev/null
ARCHMODE=`head -1 /home/dmdba/arch.buf|tr -s "  " |cut -d " " -f 2`
if [ $ARCHMODE = "Y" ] 
        then
                echo ""
        else
                echo "未打开归档:-1"
echo  $((a9=a9-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_arch_dest.sql >/dev/null
ARCHDEST=`head -1 /home/dmdba/arch_dest.buf|tr -s "  " |cut -d " " -f 2`
if [ $ARCHDEST = "/dm/arch" ] 
        then
                echo ""
        else
                echo "归档路径错误:-1"
echo  $((a9=a9-1)) >/dev/null
fi

$DMPATH/disql -s $conn_s \`/var/local/sc/rw_arch_file.sql >/dev/null
ARCHFILE=`head -1 /home/dmdba/arch_file.buf|tr -s "  " |cut -d " " -f 2`
if [ $ARCHFILE == 128 ] 
        then
                echo ""
        else
                echo "归档文件大小错误:-1"
echo  $((a9=a9-1)) >/dev/null
fi

if [ -d /dm/backup/ ]
	then
		echo ""
	else 
		echo "备份指定路径不存在:-1"
echo  $((a9=a9-1)) >/dev/null
fi

FULLBAK=`find /dm/backup  -name *.meta|grep "meta"|wc -l`
if [ $FULLBAK == 1 ]
        then
                echo ""
     else
                   echo "整库备份不存在:-3"
echo  $((a9=a9-3)) >/dev/null
fi

if [ -f "/dm/backup/dmexam.dmp" ] &&  [ -f "/dm/backup/dmexam.log" ]
	then
		echo ""
	 else
		   echo "未做逻辑备份:-3"
	    echo  $((a9=a9-3)) >/dev/null
fi


echo "***第1题数据库卸载得分***:"`echo $a1`
a1n=`awk 'BEGIN{printf "%.2f\n",('$a1'/4)}'`
echo "***第2题重新安装部署数据库得分***:"`echo $a2`
a2n=`awk 'BEGIN{printf "%.2f\n",('$a2'/14)}'`
echo "***第3题表空间及用户规划得分***:"`echo $a3`
a3n=`awk 'BEGIN{printf "%.2f\n",('$a3'/8)}'`
echo "***第4题表管理及数据导出得分***:"`echo $a4`
a4n=`awk 'BEGIN{printf "%.2f\n",('$a4'/18)}'`
echo "***第5题创建试图得分***:"`echo $a5`
a5n=`awk 'BEGIN{printf "%.2f\n",('$a5'/8)}'`
echo "***第6题数据库开发得分***:"`echo $a6`
a6n=`awk 'BEGIN{printf "%.2f\n",('$a6'/20)}'`
echo "***第7题定时作业得分***:"`echo $a7`
a7n=`awk 'BEGIN{printf "%.2f\n",('$a7'/8)}'`
echo "***第8题性能优化得分***:"`echo $a8`
a8n=`awk 'BEGIN{printf "%.2f\n",('$a8'/10)}'`
echo "***第9题数据库安全得分***:"`echo $a9`
a10n=`awk 'BEGIN{printf "%.2f\n",('$a9'/10)}'`

echo "总得分："`echo  $((tol=a1+a2+a3+a4+a5+a6+a7+a8+a9)) `
a10n=`echo  $((tol=a1+a2+a3+a4+a5+a6+a7+a8+a9)) `

